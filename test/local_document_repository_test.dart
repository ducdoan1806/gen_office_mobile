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
