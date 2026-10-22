import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/documents/data/legacy_doc_converter.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';

class TestDocConverter extends LegacyDocConverter {
  bool fail = false;
  static const ole = [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1];
  @override
  Future<Uint8List> toDocx(Uint8List bytes) async {
    if (fail) throw StateError('conversion failed');
    return Uint8List.fromList([80, 75, 3, 4, bytes.last]);
  }

  @override
  Future<Uint8List> toDoc(Uint8List bytes) async {
    if (fail) throw StateError('conversion failed');
    return Uint8List.fromList([...ole, bytes.last]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'DOC keeps source format, converted cache and fingerprint through restart; failed conversion never writes source',
    () async {
      final root = await Directory.systemTemp.createTemp('legacy-doc-');
      addTearDown(() => root.delete(recursive: true));
      final converter = TestDocConverter();
      var source = Uint8List.fromList([...TestDocConverter.ole, 1]);
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidDocumentFiles.channel, (call) async {
            if (call.method == 'write') {
              writes++;
              source = (call.arguments as Map)['bytes'] as Uint8List;
              return null;
            }
            if (call.method == 'read') return source;
            throw StateError('unexpected source operation');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidDocumentFiles.channel, null),
      );
      LocalDocumentRepository repository() => LocalDocumentRepository(
        documentsDirectory: () async => root,
        converter: converter,
      );
      final doc = await repository().storeDocx(
        'Báo cáo.DOC',
        source,
        sourceUri: 'content://source/doc',
        legacyDoc: true,
      );
      expect(writes, 0);
      expect(doc.legacyDoc, isTrue);
      expect(doc.editorName, 'Báo cáo.docx');
      final restored = (await repository().list()).single;
      expect(restored.legacyDoc, isTrue);
      expect(restored.sourceHash, sha256.convert(source).toString());
      expect(await File(restored.filePath!).readAsBytes(), [80, 75, 3, 4, 1]);
      final backup = File(
        '${File(restored.filePath!).parent.path}/original-source.doc',
      );
      expect(await backup.readAsBytes(), [...TestDocConverter.ole, 1]);
      final edited = Uint8List.fromList([80, 75, 3, 4, 2]);
      converter.fail = true;
      await expectLater(
        repository().updateDocx(doc.id, edited),
        throwsStateError,
      );
      expect(writes, 0);
      expect(source.last, 1);
      converter.fail = false;
      final saved = await repository().updateDocx(doc.id, edited);
      expect(writes, 1);
      expect(source, [...TestDocConverter.ole, 2]);
      expect(saved.sourceHash, sha256.convert(source).toString());
      expect(saved.sizeBytes, source.length);
      expect(await File(saved.filePath!).readAsBytes(), edited);
      expect(await backup.readAsBytes(), [...TestDocConverter.ole, 1]);
      expect(await repository().list(), hasLength(1));
    },
  );
}
