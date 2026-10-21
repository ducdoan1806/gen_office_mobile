import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gen_office_mobile/features/editor/data/webview_document_editor_bridge.dart';
import 'package:gen_office_mobile/app/dependencies.dart';
import 'package:gen_office_mobile/features/ai/data/mock_factory_ai_service.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/presentation/document_library_page.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';
import 'package:gen_office_mobile/features/editor/presentation/mobile_docx_editor_page.dart';

Future<void> until(WidgetTester tester, bool Function() predicate) async {
  for (var i = 0; i < 450; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    if (predicate()) return;
  }
  throw StateError('Recovery UI timed out');
}

/// Two separate Flutter runs. The host force-stops the app after PREPARED,
/// then launches phase=restore. No production files or app data are deleted.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'RECOVERY_PHASE',
    defaultValue: 'disabled',
  );
  const run = String.fromEnvironment(
    'RECOVERY_TEST_RUN',
    defaultValue: 'step6',
  );
  const sourceUri = 'content://genoffice.test/source';
  testWidgets('recovery survives Android process termination ($phase)', (
    tester,
  ) async {
    final root = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/recovery-process-$run',
    );
    final source = File('${root.path}/source.docx');
    final repository = LocalDocumentRepository(
      documentsDirectory: () async => root,
    );
    final recovery = DocumentRecoveryStore(
      documentsDirectory: () async => root,
    );
    var failWrites = false;
    late WebViewDocumentEditorBridge bridge;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDocumentFiles.channel, (call) async {
          if ((call.arguments as Map)['uri'] != sourceUri) {
            throw StateError('Unexpected source URI');
          }
          if (call.method == 'read') return source.readAsBytes();
          if (call.method == 'write') {
            if (failWrites) {
              throw PlatformException(code: 'test_permission_denied');
            }
            await source.writeAsBytes(
              (call.arguments as Map)['bytes'] as Uint8List,
              flush: true,
            );
            return null;
          }
          throw StateError('Unexpected file operation');
        });
    if (phase == 'prepare') {
      await root.create(recursive: true);
      expect(
        await repository.list(),
        isEmpty,
        reason: 'Use a fresh RECOVERY_TEST_RUN',
      );
      final original = (await rootBundle.load(
        'assets/samples/factory-demo.docx',
      )).buffer.asUint8List();
      await source.writeAsBytes(original, flush: true);
      final document = await repository.storeDocx(
        'process-test.docx',
        original,
        sourceUri: sourceUri,
      );
      var ready = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MobileDocxEditorPage(
            document: document,
            documents: repository,
            recoveryStore: recovery,
            onBridgeCreated: (value) => bridge = value,
            onReady: () => ready = true,
          ),
        ),
      );
      await until(tester, () => ready);
      final controller = bridge.controller;
      await tester.runAsync(
        () => controller.runJavaScript("""
        const e=document.querySelector('.ProseMirror'); e.focus();
        const r=document.createRange();r.selectNodeContents(e.querySelector('p'));r.collapse(false);
        const s=window.getSelection();s.removeAllRanges();s.addRange(r);
        document.execCommand('insertText',false,' — bản phục hồi sau dừng tiến trình');
      """),
      );
      RecoverySnapshot? snapshot;
      for (var i = 0; i < 150 && snapshot == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          snapshot = await recovery.find(document.id);
        });
      }
      expect(snapshot, isNotNull);
      expect(
        await source.readAsBytes(),
        original,
        reason: 'Checkpoint must never write the source',
      );
      final zip = ZipDecoder().decodeBytes(await snapshot!.read());
      expect(
        utf8.decode(zip.findFile('word/document.xml')!.content as List<int>),
        contains('bản phục hồi'),
      );
      // Simulate another app changing the source after the snapshot was written.
      final external = ZipDecoder().decodeBytes(original);
      external.addFile(
        ArchiveFile('external-test.txt', 7, utf8.encode('changed')),
      );
      await source.writeAsBytes(ZipEncoder().encode(external)!, flush: true);
      debugPrint('GENOFFICE_RECOVERY_PREPARED');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(minutes: 3)),
      );
      fail('Host must force-stop the app after GENOFFICE_RECOVERY_PREPARED');
    } else {
      expect(
        await root.exists(),
        true,
        reason: 'Run prepare and force-stop first',
      );
      final before = await source.readAsBytes();
      final document = (await repository.list()).single;
      expect((await recovery.list()).single.document.id, document.id);
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentLibraryPage(
            dependencies: AppDependencies(
              documents: repository,
              ai: MockFactoryAiService(),
            ),
            recoveryStore: recovery,
            onBridgeCreated: (value) => bridge = value,
          ),
        ),
      );
      await until(
        tester,
        () => find
            .byKey(ValueKey('restore-${document.id}'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(find.byKey(ValueKey('restore-${document.id}')));
      bool enabled() {
        final button = find.byKey(const Key('save-docx'));
        return button.evaluate().isNotEmpty &&
            tester.widget<IconButton>(button).onPressed != null;
      }

      await until(tester, enabled);
      final controller = bridge.controller;
      final text = await tester.runAsync(
        () => controller.runJavaScriptReturningResult(
          "document.querySelector('.ProseMirror').textContent",
        ),
      );
      expect(text.toString(), contains('bản phục hồi sau dừng tiến trình'));
      // Restored content must still be dirty, with a real close/discard guard.
      await tester.pageBack();
      await until(
        tester,
        () => find.text('Thay đổi chưa lưu').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();
      Future<void> saveWithConflict(String choice) async {
        await until(tester, enabled);
        await tester.tap(find.byKey(const Key('save-docx')));
        await until(
          tester,
          () => find.text('File gốc đã thay đổi').evaluate().isNotEmpty,
        );
        await tester.tap(find.text(choice));
        await until(tester, enabled);
      }

      await saveWithConflict('Hủy');
      expect(await source.readAsBytes(), before);
      expect(await recovery.find(document.id), isNotNull);
      failWrites = true;
      await saveWithConflict('Ghi đè file gốc');
      expect(await source.readAsBytes(), before);
      expect(await recovery.find(document.id), isNotNull);
      failWrites = false;
      await saveWithConflict('Ghi đè file gốc');
      expect(await recovery.find(document.id), isNull);
      final saved = ZipDecoder().decodeBytes(await source.readAsBytes());
      expect(
        utf8.decode(saved.findFile('word/document.xml')!.content as List<int>),
        contains('bản phục hồi'),
      );
      expect(await repository.list(), hasLength(1));
      await tester.pageBack();
      await until(
        tester,
        () => find.byKey(const Key('import-docx')).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.text('Có tài liệu chưa lưu'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await root.delete(recursive: true);
    }
  }, skip: phase != 'prepare' && phase != 'restore');
}
