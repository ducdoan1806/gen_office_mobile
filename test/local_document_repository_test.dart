import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';

void main() {
  late Directory directory;
  late LocalDocumentRepository repository;
  final bytes = Uint8List.fromList([80, 75, 3, 4, 1, 2, 3]);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('genoffice-library-');
    repository = LocalDocumentRepository(
      documentsDirectory: () async => directory,
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test('new library is empty without creating demo files', () async {
    expect(await repository.list(), isEmpty);
  });

  test('saving twice updates one library item and survives restart', () async {
    final original = await repository.storeDocx('Quy trình.docx', bytes);
    final first = await repository.updateDocx(
      original.id,
      Uint8List.fromList([...bytes, 8]),
    );
    final latestBytes = Uint8List.fromList([...bytes, 9, 10]);
    final second = await repository.updateDocx(original.id, latestBytes);
    expect(first.id, original.id);
    expect(second.name, original.name);
    expect(second.createdAt, original.createdAt);
    expect(second.updatedAt!.isBefore(original.createdAt!), false);
    final restarted = LocalDocumentRepository(
      documentsDirectory: () async => directory,
    );
    final loaded = (await restarted.list()).single;
    expect(loaded.id, original.id);
    expect(loaded.sizeBytes, latestBytes.length);
    expect(loaded.updatedAt, second.updatedAt);
    expect(await File(loaded.filePath!).readAsBytes(), latestBytes);
    final retained = await File(loaded.filePath!).parent
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.docx'))
        .toList();
    expect(retained, hasLength(2));
  });

  test(
    'save targets the ID including older exports, never the display name',
    () async {
      final first = await repository.storeDocx('report.docx', bytes);
      final second = await repository.storeDocx(
        'report.docx',
        bytes,
        isExport: true,
      );
      final changed = Uint8List.fromList([...bytes, 42]);
      final updated = await repository.updateDocx(second.id, changed);
      final loaded = await repository.list();
      expect(loaded, hasLength(2));
      expect(loaded.first.id, second.id);
      expect(await File(first.filePath!).readAsBytes(), bytes);
      expect(await File(updated.filePath!).readAsBytes(), changed);
    },
  );

  test('invalid saves preserve committed bytes and metadata', () async {
    final document = await repository.storeDocx('report.docx', bytes);
    final metadata = File(
      '${File(document.filePath!).parent.path}/document.json',
    );
    final before = await metadata.readAsString();
    await expectLater(
      repository.updateDocx(document.id, Uint8List(0)),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateDocx(
        document.id,
        Uint8List(LocalDocumentRepository.maxExportBytes + 1),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateDocx('../outside', bytes),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateDocx('00000000000000000000000000000000', bytes),
      throwsStateError,
    );
    expect(await metadata.readAsString(), before);
    expect(await File(document.filePath!).readAsBytes(), bytes);
    expect(await repository.list(), hasLength(1));
  });

  test(
    'legacy metadata and abandoned writes keep the committed document readable',
    () async {
      final document = await repository.storeDocx('legacy.docx', bytes);
      final folder = File(document.filePath!).parent;
      final metadata = File('${folder.path}/document.json');
      final legacy =
          jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      legacy.remove('updatedAt');
      await metadata.writeAsString(jsonEncode(legacy));
      final abandoned = File(
        '${folder.path}/content-11111111111111111111111111111111.docx',
      );
      await abandoned.writeAsBytes([0, 1, 2]);
      final loaded = (await repository.list()).single;
      expect(loaded.updatedAt, loaded.createdAt);
      expect(await File(loaded.filePath!).readAsBytes(), bytes);
      final updated = await repository.updateDocx(
        document.id,
        Uint8List.fromList([...bytes, 7]),
      );
      expect(await abandoned.exists(), false);
      expect(await File(updated.filePath!).readAsBytes(), [...bytes, 7]);
    },
  );

  test(
    'simultaneous saves through repository instances keep one valid pointer',
    () async {
      final document = await repository.storeDocx('report.docx', bytes);
      final other = LocalDocumentRepository(
        documentsDirectory: () async => directory,
      );
      final changedA = Uint8List.fromList([...bytes, 1]);
      final changedB = Uint8List.fromList([...bytes, 2]);
      await Future.wait([
        repository.updateDocx(document.id, changedA),
        other.updateDocx(document.id, changedB),
      ]);
      final loaded = (await repository.list()).single;
      expect(
        await File(loaded.filePath!).readAsBytes(),
        anyOf(equals(changedA), equals(changedB)),
      );
      expect(loaded.id, document.id);
    },
  );

  test(
    'metadata content filenames cannot read outside the document folder',
    () async {
      final document = await repository.storeDocx('report.docx', bytes);
      final metadata = File(
        '${File(document.filePath!).parent.path}/document.json',
      );
      final data =
          jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      data['contentFile'] = '../../outside.docx';
      await metadata.writeAsString(jsonEncode(data));
      await expectLater(repository.list(), throwsFormatException);
      await expectLater(
        repository.updateDocx(document.id, bytes),
        throwsFormatException,
      );
    },
  );

  test('import owns its bytes and restores metadata after restart', () async {
    final source = File('${directory.path}/Quy trình.docx');
    await source.writeAsBytes(bytes);
    final saved = await repository.storeDocx(
      'Quy trình.docx',
      await source.readAsBytes(),
    );
    await source.delete();
    final restarted = LocalDocumentRepository(
      documentsDirectory: () async => directory,
    );
    final loaded = (await restarted.list()).single;
    expect(loaded.id, saved.id);
    expect(loaded.name, 'Quy trình.docx');
    expect(loaded.createdAt, saved.createdAt);
    expect(loaded.sizeBytes, bytes.length);
    expect(await File(loaded.filePath!).readAsBytes(), bytes);
  });

  test(
    'same-name imports and saved copies never overwrite the original',
    () async {
      final original = await repository.storeDocx('report.docx', bytes);
      final duplicate = await repository.storeDocx('report.docx', bytes);
      final edited = Uint8List.fromList([...bytes, 9]);
      final exported = await repository.storeDocx(
        'report.docx',
        edited,
        isExport: true,
      );
      expect({original.id, duplicate.id, exported.id}, hasLength(3));
      final loaded = await repository.list();
      expect(loaded, hasLength(3));
      expect(loaded.first.id, exported.id);
      expect(await File(original.filePath!).readAsBytes(), bytes);
      expect(await File(exported.filePath!).readAsBytes(), edited);
      expect(exported.filePath, contains('/exports/'));
    },
  );

  test('ignores incomplete imports and unrelated filesystem entries', () async {
    await repository.storeDocx('ready.docx', bytes);
    await Directory(
      '${directory.path}/GenOffice/documents/.partial.tmp',
    ).create();
    await File(
      '${directory.path}/GenOffice/documents/notes.txt',
    ).writeAsString('notes');
    expect(await repository.list(), hasLength(1));
  });

  test(
    'names cannot escape app storage and invalid inputs add no entries',
    () async {
      final saved = await repository.storeDocx('../../outside.docx', bytes);
      expect(saved.name, 'outside.docx');
      expect(saved.filePath, startsWith(directory.path));
      await expectLater(
        repository.storeDocx('report.pdf', bytes),
        throwsArgumentError,
      );
      await expectLater(
        repository.storeDocx('empty.docx', Uint8List(0)),
        throwsArgumentError,
      );
      await expectLater(
        repository.storeDocx(
          'large.docx',
          Uint8List(LocalDocumentRepository.maxImportBytes + 1),
        ),
        throwsArgumentError,
      );
      expect(await repository.list(), hasLength(1));
    },
  );

  test(
    'restores paths when the app documents directory is relocated',
    () async {
      await repository.storeDocx('moved.docx', bytes);
      final relocated = Directory('${directory.path}/relocated');
      await relocated.create();
      await Directory(
        '${directory.path}/GenOffice',
      ).rename('${relocated.path}/GenOffice');
      final reopened = LocalDocumentRepository(
        documentsDirectory: () async => relocated,
      );
      final saved = (await reopened.list()).single;
      expect(await File(saved.filePath!).readAsBytes(), bytes);
      expect(saved.filePath, startsWith(relocated.path));
    },
  );

  test(
    'metadata corruption reports an error without replacing the library',
    () async {
      final saved = await repository.storeDocx('report.docx', bytes);
      final metadata = File(
        '${File(saved.filePath!).parent.path}/document.json',
      );
      await metadata.writeAsString('{broken');
      await expectLater(repository.list(), throwsFormatException);
      expect(await File(saved.filePath!).readAsBytes(), bytes);
      expect(await metadata.readAsString(), '{broken');
    },
  );
}
