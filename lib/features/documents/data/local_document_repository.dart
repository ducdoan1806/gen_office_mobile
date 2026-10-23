import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'legacy_doc_converter.dart';
import 'csv_workbook_codec.dart';
import 'dart:isolate';

import '../domain/document_repository.dart';
import 'android_document_files.dart';
import '../domain/office_document.dart';

/// Each document is committed with its metadata by renaming a staged directory.
/// Paths in metadata are relative, since iOS can relocate the app container.
class LocalDocumentRepository implements DocumentRepository {
  LocalDocumentRepository({
    Future<Directory> Function()? documentsDirectory,
    AndroidDocumentFiles sourceFiles = const AndroidDocumentFiles(),
    LegacyDocConverter converter = const LegacyDocConverter(),
  }) : _sourceFiles = sourceFiles,
       _converter = converter,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  final AndroidDocumentFiles _sourceFiles;
  final LegacyDocConverter _converter;
  static const maxImportBytes = 20 * 1024 * 1024;
  static const maxExportBytes = 32 * 1024 * 1024;
  static final _idPattern = RegExp(r'^[a-f0-9]{32}$');
  static final _contentPattern = RegExp(
    r'^content-[a-f0-9]{32}\.(docx|xlsx|pptx)$',
  );
  static final _writes = <String, Future<void>>{};

  String _newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  String _contentFile(Map<String, dynamic> data) {
    if (data['format'] == 'pdf') {
      if (data['contentFile'] != 'content.pdf') {
        throw const FormatException('Metadata PDF không hợp lệ.');
      }
      return 'content.pdf';
    }
    final extension = data['format'] as String;
    final name = data['contentFile'] ?? 'content.$extension';
    if (name is! String ||
        (!name.endsWith('.$extension') ||
            (name != 'content.$extension' &&
                !_contentPattern.hasMatch(name)))) {
      throw const FormatException('Đường dẫn tài liệu không hợp lệ.');
    }
    return name;
  }

  Future<Map<String, dynamic>> _metadata(Directory directory, String id) async {
    final data =
        jsonDecode(await File('${directory.path}/document.json').readAsString())
            as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['id'] != id ||
        !['docx', 'pdf', 'xlsx', 'pptx'].contains(data['format'])) {
      throw const FormatException('Metadata tài liệu không hợp lệ.');
    }
    _contentFile(data);
    return data;
  }

  OfficeDocument _document(Directory directory, Map<String, dynamic> data) =>
      OfficeDocument(
        id: data['id'] as String,
        name: data['name'] as String,
        format: DocumentFormat.values.byName(data['format'] as String),
        filePath: '${directory.path}/${_contentFile(data)}',
        sourceUri: data['sourceUri'] as String?,
        createdAt: DateTime.parse(data['createdAt'] as String),
        updatedAt: DateTime.parse(
          (data['updatedAt'] ?? data['createdAt']) as String,
        ),
        sizeBytes: data['sizeBytes'] as int,
        legacyDoc: data['legacyDoc'] == true,
        sourceHash: data['sourceHash'] as String?,
      );

  Future<Directory> _root() async =>
      Directory('${(await _documentsDirectory()).path}/GenOffice');

  @override
  Future<OfficeDocument> storePdf(
    String name,
    Uint8List bytes, {
    String? sourceUri,
  }) async {
    name = name.split(RegExp(r'[/\\]')).last.trim();
    if (!name.toLowerCase().endsWith('.pdf') ||
        name.length <= 4 ||
        name.contains(RegExp(r'[\x00-\x1f]'))) {
      throw ArgumentError('Tên tài liệu PDF không hợp lệ.');
    }
    if (bytes.length < 5 ||
        bytes.length > maxImportBytes ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw ArgumentError('PDF không hợp lệ hoặc vượt giới hạn 20 MB.');
    }
    if (sourceUri != null) {
      for (final existing in await list()) {
        if (existing.sourceUri == sourceUri &&
            existing.format == DocumentFormat.pdf) {
          return existing;
        }
      }
    }
    final id = _newId();
    final parent = Directory('${(await _root()).path}/documents');
    await parent.create(recursive: true);
    final staging = await Directory('${parent.path}/.$id.tmp').create();
    final data = <String, dynamic>{
      'version': 1,
      'id': id,
      'name': name,
      'format': 'pdf',
      'contentFile': 'content.pdf',
      if (sourceUri != null) 'sourceUri': sourceUri,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'sizeBytes': bytes.length,
    };
    try {
      await File(
        '${staging.path}/content.pdf',
      ).writeAsBytes(bytes, flush: true);
      await File(
        '${staging.path}/document.json',
      ).writeAsString(jsonEncode(data), flush: true);
      return _document(await staging.rename('${parent.path}/$id'), data);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<OfficeDocument> storeDocx(
    String name,
    Uint8List bytes, {
    bool isExport = false,
    bool legacyDoc = false,
    String? sourceUri,
  }) => storeOffice(
    name,
    bytes,
    format: DocumentFormat.docx,
    isExport: isExport,
    legacyDoc: legacyDoc,
    sourceUri: sourceUri,
  );

  @override
  Future<OfficeDocument> storeOffice(
    String name,
    Uint8List bytes, {
    required DocumentFormat format,
    bool isExport = false,
    bool legacyDoc = false,
    String? sourceUri,
  }) async {
    if (![
          DocumentFormat.docx,
          DocumentFormat.xlsx,
          DocumentFormat.pptx,
        ].contains(format) ||
        (legacyDoc && format != DocumentFormat.docx)) {
      throw ArgumentError('Định dạng không hỗ trợ sửa.');
    }
    final extension = format.name;
    // The display name is never used as a filesystem path.
    name = name.split(RegExp(r'[/\\]')).last.trim();
    final sourceExtension = name.toLowerCase().split('.').last;
    final converted = sourceExtension != extension;
    final validExtensions = switch (format) {
      DocumentFormat.docx => legacyDoc ? ['doc'] : ['docx'],
      DocumentFormat.xlsx => ['xlsx', 'xls', 'csv'],
      DocumentFormat.pptx => ['pptx', 'ppt'],
      _ => <String>[],
    };
    if (!validExtensions.contains(sourceExtension) ||
        name.length <= sourceExtension.length + 1 ||
        name.contains(RegExp(r'[\x00-\x1f]'))) {
      throw ArgumentError('Tên tài liệu không hợp lệ.');
    }
    final limit = isExport ? maxExportBytes : maxImportBytes;
    if (bytes.isEmpty || bytes.length > limit) {
      throw ArgumentError(
        'Tài liệu phải có nội dung và không vượt ${limit ~/ (1024 * 1024)} MB.',
      );
    }
    if (sourceUri != null) {
      for (final existing in await list()) {
        if (existing.sourceUri == sourceUri &&
            existing.format == format &&
            existing.legacyDoc == legacyDoc) {
          return existing;
        }
      }
    }
    final sourceLength = bytes.length;
    final originalDoc = converted ? bytes : null;
    final sourceHash = converted ? sha256.convert(bytes).toString() : null;
    if (converted) {
      final input = bytes;
      bytes = sourceExtension == 'csv'
          ? await Isolate.run(() => CsvWorkbookCodec.toXlsx(input))
          : await _converter.convertOffice(bytes, sourceExtension, extension);
      if (bytes.length > maxExportBytes ||
          bytes.length < 4 ||
          bytes[0] != 80 ||
          bytes[1] != 75) {
        throw StateError(
          'Kết quả chuyển đổi tài liệu không hợp lệ hoặc vượt 32 MB.',
        );
      }
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
      if (originalDoc != null) {
        await File(
          '${staging.path}/original-source.$sourceExtension',
        ).writeAsBytes(originalDoc, flush: true);
      }
      await File(
        '${staging.path}/content.$extension',
      ).writeAsBytes(bytes, flush: true);
      await File('${staging.path}/document.json').writeAsString(
        jsonEncode({
          'version': 1,
          'id': id,
          'name': name,
          'format': extension,
          if (legacyDoc) 'legacyDoc': true,
          if (sourceHash != null) 'sourceHash': sourceHash,
          if (sourceUri != null) 'sourceUri': sourceUri,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': createdAt.toIso8601String(),
          'sizeBytes': sourceLength,
        }),
        flush: true,
      );
      final committed = await staging.rename('${parent.path}/$id');
      return OfficeDocument(
        id: id,
        name: name,
        format: format,
        filePath: '${committed.path}/content.$extension',
        sourceUri: sourceUri,
        createdAt: createdAt,
        updatedAt: createdAt,
        sizeBytes: sourceLength,
        legacyDoc: legacyDoc,
        sourceHash: sourceHash,
      );
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<OfficeDocument> updateDocx(
    String id,
    Uint8List bytes, {
    String? sourceUri,
  }) => updateOffice(id, bytes, sourceUri: sourceUri);

  @override
  Future<OfficeDocument> updateOffice(
    String id,
    Uint8List bytes, {
    String? sourceUri,
  }) async {
    if (!_idPattern.hasMatch(id)) {
      throw ArgumentError('ID tài liệu không hợp lệ.');
    }
    if (bytes.isEmpty || bytes.length > maxExportBytes) {
      throw ArgumentError('Tài liệu phải có nội dung và không vượt 32 MB.');
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
      if (data['format'] == 'pdf') throw StateError('PDF chỉ hỗ trợ xem.');
      final extension = data['format'] as String;
      final oldContent = _contentFile(data);
      final revision = _newId();
      final document = _document(directory, data);
      final Uint8List sourceBytes;
      if (document.sourceExtension == 'csv') {
        final template = await File(
          '${directory.path}/original-source.csv',
        ).readAsBytes();
        sourceBytes = await Isolate.run(
          () => CsvWorkbookCodec.fromXlsx(bytes, template),
        );
      } else if (document.needsConversion) {
        sourceBytes = await _converter.convertOffice(
          bytes,
          extension,
          document.sourceExtension,
        );
      } else {
        sourceBytes = bytes;
      }
      if (sourceBytes.length > maxExportBytes || sourceBytes.isEmpty) {
        throw StateError('Kết quả chuyển đổi vượt giới hạn 32 MB.');
      }
      final content = File('${directory.path}/content-$revision.$extension');
      final metadata = File('${directory.path}/.document-$revision.tmp');
      final updated = <String, dynamic>{
        ...data,
        if (sourceUri != null) 'sourceUri': sourceUri,
        'contentFile': 'content-$revision.$extension',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'sizeBytes': sourceBytes.length,
        if (document.needsConversion)
          'sourceHash': sha256.convert(sourceBytes).toString(),
      };
      try {
        await content.writeAsBytes(bytes, flush: true);
        await metadata.writeAsString(jsonEncode(updated), flush: true);
        final target = updated['sourceUri'] as String?;
        if (target != null) await _sourceFiles.write(target, sourceBytes);
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
              (RegExp(r'^content\.(docx|xlsx|pptx)$').hasMatch(name) ||
                  _contentPattern.hasMatch(name)) &&
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
