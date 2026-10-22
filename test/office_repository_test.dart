import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final format in [DocumentFormat.xlsx, DocumentFormat.pptx]) {
    test(
      '${format.name} source save retains ID, extension and recovery format',
      () async {
        final root = await Directory.systemTemp.createTemp('genoffice-office-');
        addTearDown(() => root.delete(recursive: true));
        final bytes = await File(
          'assets/samples/${format == DocumentFormat.xlsx ? 'sheets-test.xlsx' : 'slides-test.pptx'}',
        ).readAsBytes();
        final writes = <Uint8List>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidDocumentFiles.channel, (
              call,
            ) async {
              if (call.method == 'write') {
                writes.add((call.arguments as Map)['bytes'] as Uint8List);
                return null;
              }
              throw StateError('Unexpected method');
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(AndroidDocumentFiles.channel, null),
        );
        LocalDocumentRepository repo() =>
            LocalDocumentRepository(documentsDirectory: () async => root);
        final imported = await repo().storeOffice(
          'test.${format.name}',
          bytes,
          format: format,
          sourceUri: 'content://qa/${format.name}',
        );
        expect(imported.format, format);
        expect(imported.filePath, endsWith('.${format.name}'));
        final saved = await repo().updateOffice(imported.id, bytes);
        expect(saved.id, imported.id);
        expect(writes.single, bytes);
        final recent = await repo().list();
        expect(recent, hasLength(1));
        expect(recent.single.format, format);
        expect(await File(recent.single.filePath!).readAsBytes(), bytes);
        final recovery = DocumentRecoveryStore(
          documentsDirectory: () async => root,
        );
        await recovery.write(
          saved,
          bytes,
          baseHash: DocumentRecoveryStore.hash(bytes),
        );
        final snapshots = await recovery.list();
        expect(snapshots.single.document.format, format);
        expect(await snapshots.single.read(), bytes);
      },
    );
    test(
      '${format.name} failed original write keeps the committed cache',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'genoffice-office-error-',
        );
        addTearDown(() => root.delete(recursive: true));
        final bytes = Uint8List.fromList([80, 75, 3, 4]);
        final repo = LocalDocumentRepository(
          documentsDirectory: () async => root,
        );
        final doc = await repo.storeOffice(
          'test.${format.name}',
          bytes,
          format: format,
          sourceUri: 'content://qa/failure',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              AndroidDocumentFiles.channel,
              (call) async =>
                  throw PlatformException(code: 'permission_denied'),
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(AndroidDocumentFiles.channel, null),
        );
        await expectLater(
          repo.updateOffice(doc.id, Uint8List.fromList([80, 75, 5, 6])),
          throwsA(isA<PlatformException>()),
        );
        expect(
          await File((await repo.list()).single.filePath!).readAsBytes(),
          bytes,
        );
      },
    );
  }
}
