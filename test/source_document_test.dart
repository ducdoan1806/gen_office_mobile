import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LocalDocumentRepository repository;
  late Map<String, Uint8List> sources;
  final original = Uint8List.fromList([80, 75, 3, 4, 1]);
  final edited = Uint8List.fromList([80, 75, 3, 4, 2, 3]);
  const uri = 'content://documents/original';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('genoffice-source-');
    repository = LocalDocumentRepository(
      documentsDirectory: () async => directory,
    );
    sources = {uri: original};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDocumentFiles.channel, (call) async {
          final args = call.arguments as Map?;
          switch (call.method) {
            case 'open':
              return {
                'uri': uri,
                'name': 'original.docx',
                'bytes': sources[uri],
              };
            case 'read':
              if (!sources.containsKey(args!['uri'])) {
                throw PlatformException(code: 'revoked');
              }
              return sources[args['uri']];
            case 'write':
              if (!sources.containsKey(args!['uri'])) {
                throw PlatformException(code: 'revoked');
              }
              sources[args['uri'] as String] = args['bytes'] as Uint8List;
              return null;
          }
          throw StateError('Unexpected method ${call.method}');
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDocumentFiles.channel, null);
    await directory.delete(recursive: true);
  });

  test('picker retains actual name, bytes and durable source URI', () async {
    final picked = (await const AndroidDocumentFiles().pick())!;
    expect(picked.name, 'original.docx');
    expect(picked.sourceUri, uri);
    expect(await picked.readAsBytes(), original);
  });

  test(
    'save writes source and keeps one recent entry across repository restart',
    () async {
      final document = await repository.storeDocx(
        'original.docx',
        original,
        sourceUri: uri,
      );
      await repository.updateDocx(document.id, edited);
      expect(sources[uri], edited);
      repository = LocalDocumentRepository(
        documentsDirectory: () async => directory,
      );
      final reopened = (await repository.list()).single;
      expect(reopened.sourceUri, uri);
      expect(
        await const AndroidDocumentFiles().read(reopened.sourceUri!),
        edited,
      );
      expect(
        (await repository.storeDocx(
          'original.docx',
          edited,
          sourceUri: uri,
        )).id,
        document.id,
      );
      expect(await repository.list(), hasLength(1));
      sources[uri] =
          original; // Changed externally: reopening must read the source.
      expect(
        await const AndroidDocumentFiles().read(reopened.sourceUri!),
        original,
      );
    },
  );

  test(
    'failed source write leaves committed cache and metadata unchanged',
    () async {
      final document = await repository.storeDocx(
        'original.docx',
        original,
        sourceUri: uri,
      );
      sources.remove(uri);
      await expectLater(
        repository.updateDocx(document.id, edited),
        throwsA(isA<PlatformException>()),
      );
      final current = (await repository.list()).single;
      expect(
        File(current.filePath!).absolute.uri,
        File(document.filePath!).absolute.uri,
      );
      expect(await File(current.filePath!).readAsBytes(), original);
    },
  );

  test(
    'legacy item can explicitly link to original file without another item',
    () async {
      final legacy = await repository.storeDocx('original.docx', original);
      await repository.updateDocx(legacy.id, edited, sourceUri: uri);
      expect(sources[uri], edited);
      expect((await repository.list()).single.sourceUri, uri);
      await repository.updateDocx(legacy.id, original);
      expect(sources[uri], original);
    },
  );
}
