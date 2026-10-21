import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../domain/document_repository.dart';
import '../domain/office_document.dart';

/// Each document is committed with its metadata by renaming a staged directory.
/// Paths in metadata are relative, since iOS can relocate the app container.
class LocalDocumentRepository implements DocumentRepository {
  LocalDocumentRepository({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  static const maxImportBytes = 20 * 1024 * 1024;
  static const maxExportBytes = 32 * 1024 * 1024;
  static final _idPattern = RegExp(r'^[a-f0-9]{32}$');
  static final _contentPattern = RegExp(r'^content-[a-f0-9]{32}\.docx$');
  static final _writes = <String, Future<void>>{};

  String _newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  String _contentFile(Map<String, dynamic> data) {
    final name = data['contentFile'] ?? 'content.docx';
    if (name is! String ||
        (name != 'content.docx' && !_contentPattern.hasMatch(name))) {
      throw const FormatException('Đường dẫn tài liệu không hợp lệ.');
    }
    return name;
  }

  Future<Map<String, dynamic>> _metadata(Directory directory, String id) async {
    final data =
        jsonDecode(await File('${directory.path}/document.json').readAsString())
            as Map<String, dynamic>;
    if (data['version'] != 1 || data['id'] != id || data['format'] != 'docx') {
      throw const FormatException('Metadata tài liệu không hợp lệ.');
    }
    _contentFile(data);
    return data;
  }

  OfficeDocument _document(Directory directory, Map<String, dynamic> data) =>
      OfficeDocument(
        id: data['id'] as String,
        name: data['name'] as String,
        format: DocumentFormat.docx,
        filePath: '${directory.path}/${_contentFile(data)}',
        createdAt: DateTime.parse(data['createdAt'] as String),
        updatedAt: DateTime.parse(
          (data['updatedAt'] ?? data['createdAt']) as String,
        ),
        sizeBytes: data['sizeBytes'] as int,
      );

  Future<Directory> _root() async =>
      Directory('${(await _documentsDirectory()).path}/GenOffice');

  @override
  Future<OfficeDocument> storeDocx(
    String name,
    Uint8List bytes, {
    bool isExport = false,
  }) async {
    // The display name is never used as a filesystem path.
    name = name.split(RegExp(r'[/\\]')).last.trim();
    if (!name.toLowerCase().endsWith('.docx') ||
        name.length <= 5 ||
        name.contains(RegExp(r'[\x00-\x1f]'))) {
      throw ArgumentError('Tên tài liệu DOCX không hợp lệ.');
    }
    final limit = isExport ? maxExportBytes : maxImportBytes;
    if (bytes.isEmpty || bytes.length > limit) {
      throw ArgumentError(
        'DOCX phải có nội dung và không vượt ${limit ~/ (1024 * 1024)} MB.',
      );
    }
    final id = _newId();
    final parent = Directory(
      '${(await _root()).path}/${isExport ? 'exports' : 'documents'}',
    );
    await parent.create(recursive: true);
    final staging = Directory('${parent.path}/.$id.tmp');
    await staging.create();
    try {
      final createdAt = DateTime.now().toUtc();
      await File(
        '${staging.path}/content.docx',
      ).writeAsBytes(bytes, flush: true);
      await File('${staging.path}/document.json').writeAsString(
        jsonEncode({
          'version': 1,
          'id': id,
          'name': name,
          'format': 'docx',
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': createdAt.toIso8601String(),
          'sizeBytes': bytes.length,
        }),
        flush: true,
      );
      final committed = await staging.rename('${parent.path}/$id');
      return OfficeDocument(
        id: id,
        name: name,
        format: DocumentFormat.docx,
        filePath: '${committed.path}/content.docx',
        createdAt: createdAt,
        updatedAt: createdAt,
        sizeBytes: bytes.length,
      );
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<OfficeDocument> updateDocx(String id, Uint8List bytes) async {
    if (!_idPattern.hasMatch(id)) {
      throw ArgumentError('ID tài liệu không hợp lệ.');
    }
    if (bytes.isEmpty || bytes.length > maxExportBytes) {
      throw ArgumentError('DOCX phải có nội dung và không vượt 32 MB.');
    }
    final root = await _root();
    Directory? directory;
    for (final folder in ['documents', 'exports']) {
      final candidate = Directory('${root.path}/$folder/$id');
      if (await candidate.exists()) {
        directory = candidate;
        break;
      }
    }
    if (directory == null) throw StateError('Không tìm thấy tài liệu cần lưu.');

    // Serialize updates across repository instances in this app isolate.
    final key = directory.absolute.path;
    final previous = _writes[key] ?? Future<void>.value();
    final finished = Completer<void>();
    _writes[key] = finished.future;
    try {
      await previous;
      final data = await _metadata(directory, id);
      final oldContent = _contentFile(data);
      final revision = _newId();
      final content = File('${directory.path}/content-$revision.docx');
      final metadata = File('${directory.path}/.document-$revision.tmp');
      final updated = <String, dynamic>{
        ...data,
        'contentFile': 'content-$revision.docx',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'sizeBytes': bytes.length,
      };
      try {
        await content.writeAsBytes(bytes, flush: true);
        await metadata.writeAsString(jsonEncode(updated), flush: true);
        // The current bytes stay readable until this final pointer replacement.
        await metadata.rename('${directory.path}/document.json');
      } catch (_) {
        for (final staged in [content, metadata]) {
          try {
            if (await staged.exists()) await staged.delete();
          } on FileSystemException {
            /* Preserve the save error. */
          }
        }
        rethrow;
      }
      // Retain the preceding committed bytes internally, without another library
      // entry. A cleanup error must not turn a committed save into a failure.
      try {
        await for (final entity in directory.list(followLinks: false)) {
          final name = entity.uri.pathSegments.last;
          if (entity is File &&
              (name == 'content.docx' || _contentPattern.hasMatch(name)) &&
              name != oldContent &&
              name != updated['contentFile']) {
            await entity.delete();
          }
        }
      } on FileSystemException {
        /* Try cleanup on the next save. */
      }
      return _document(directory, updated);
    } finally {
      finished.complete();
      if (identical(_writes[key], finished.future)) _writes.remove(key);
    }
  }

  @override
  Future<List<OfficeDocument>> list() async {
    final root = await _root();
    final documents = <OfficeDocument>[];
    for (final folder in ['documents', 'exports']) {
      final parent = Directory('${root.path}/$folder');
      if (!await parent.exists()) continue;
      await for (final entity in parent.list(followLinks: false)) {
        final id = entity.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last;
        if (entity is! Directory || !_idPattern.hasMatch(id)) continue;
        documents.add(_document(entity, await _metadata(entity, id)));
      }
    }
    documents.sort((a, b) {
      final order = b.updatedAt!.compareTo(a.updatedAt!);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return documents;
  }
}
