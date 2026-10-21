import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';

void main() {
  late Directory directory;
  late DocumentRecoveryStore store;
  const document = OfficeDocument(
    id: '../same-name',
    name: 'report.docx',
    format: DocumentFormat.docx,
    sourceUri: 'content://provider/original',
    filePath: '/cache/current.docx',
  );
  final original = Uint8List.fromList([80, 75, 3, 4, 1]);
  final latest = Uint8List.fromList([80, 75, 3, 4, 2]);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('genoffice-recovery-');
    store = DocumentRecoveryStore(documentsDirectory: () async => directory);
  });
  tearDown(() => directory.delete(recursive: true));
  test(
    'reconstructs latest complete DOCX and original reference after restart',
    () async {
      await store.write(document, original, baseHash: 'original-hash');
      await store.write(document, latest, baseHash: 'original-hash');
      final restarted = DocumentRecoveryStore(
        documentsDirectory: () async => directory,
      );
      final record = (await restarted.list()).single;
      expect(await record.read(), latest);
      expect(record.document.id, document.id);
      expect(record.document.sourceUri, document.sourceUri);
      expect(record.baseHash, 'original-hash');
    },
  );
  test(
    'ignores interrupted staging writes and falls back from corrupt latest revision',
    () async {
      await store.write(document, original, baseHash: null);
      await store.write(document, latest, baseHash: null);
      final newest = (await store.find(document.id))!;
      final group = File(newest.contentPath).parent.parent;
      final partial = Directory(
        '${group.path}/.00000000000000000000000000000000.tmp',
      );
      await partial.create();
      await File('${partial.path}/content.docx').writeAsBytes([80, 75]);
      await File(newest.contentPath).writeAsBytes([80, 75, 3, 4, 9]);
      expect(await (await store.find(document.id))!.read(), original);
      expect(await partial.exists(), true);
    },
  );
  test(
    'reports fully corrupt metadata without deleting the snapshot',
    () async {
      await store.write(document, original, baseHash: null);
      final record = (await store.find(document.id))!;
      final metadata = File(
        '${File(record.contentPath).parent.path}/snapshot.json',
      );
      await metadata.writeAsString(jsonEncode({'version': 999}));
      await expectLater(store.list(), throwsFormatException);
      expect(await File(record.contentPath).exists(), true);
    },
  );
  test('invalid new writes retain the preceding snapshot', () async {
    await store.write(document, original, baseHash: null);
    await expectLater(
      store.write(document, Uint8List(0), baseHash: null),
      throwsFormatException,
    );
    await expectLater(
      store.write(document, Uint8List.fromList([0, 0, 0, 0]), baseHash: null),
      throwsFormatException,
    );
    expect(await (await store.find(document.id))!.read(), original);
  });
  test(
    'same-name documents stay separate and discard never touches source files',
    () async {
      final source = File('${directory.path}/original.docx');
      await source.writeAsBytes(original);
      final other = OfficeDocument(
        id: 'another',
        name: document.name,
        format: DocumentFormat.docx,
        filePath: source.path,
      );
      await store.write(document, original, baseHash: null);
      await store.write(other, latest, baseHash: null);
      expect(await store.list(), hasLength(2));
      await store.clear(document.id);
      expect((await store.list()).single.document.id, other.id);
      expect(await source.readAsBytes(), original);
      await store.clear(other.id);
      expect(await store.list(), isEmpty);
    },
  );
  test('serialized writes and discard work across store instances', () async {
    final other = DocumentRecoveryStore(
      documentsDirectory: () async => directory,
    );
    await Future.wait([
      store.write(document, original, baseHash: null),
      other.write(document, latest, baseHash: null),
      store.clear(document.id),
    ]);
    expect(await other.list(), isEmpty);
    await other.write(document, latest, baseHash: null);
    expect(await (await store.find(document.id))!.read(), latest);
  });
  test('retains at most two committed revisions per document', () async {
    for (var i = 0; i < 4; i++) {
      await store.write(
        document,
        Uint8List.fromList([80, 75, 3, 4, i]),
        baseHash: null,
      );
    }
    final record = (await store.find(document.id))!;
    final revisions = await File(
      record.contentPath,
    ).parent.parent.list().toList();
    expect(revisions.whereType<Directory>(), hasLength(2));
    expect(await record.read(), [80, 75, 3, 4, 3]);
  });
}
