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
    final id = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
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
        sizeBytes: bytes.length,
      );
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
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
        final data =
            jsonDecode(
                  await File('${entity.path}/document.json').readAsString(),
                )
                as Map<String, dynamic>;
        if (data['version'] != 1 ||
            data['id'] != id ||
            data['format'] != 'docx') {
          throw const FormatException('Metadata tài liệu không hợp lệ.');
        }
        documents.add(
          OfficeDocument(
            id: id,
            name: data['name'] as String,
            format: DocumentFormat.docx,
            filePath: '${entity.path}/content.docx',
            createdAt: DateTime.parse(data['createdAt'] as String),
            sizeBytes: data['sizeBytes'] as int,
          ),
        );
      }
    }
    documents.sort((a, b) {
      final order = b.createdAt!.compareTo(a.createdAt!);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return documents;
  }
}
