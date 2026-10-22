import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gen_office_mobile/app/dependencies.dart';
import 'package:gen_office_mobile/features/ai/data/mock_factory_ai_service.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/documents/data/legacy_doc_converter.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/presentation/document_library_page.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';
import 'package:gen_office_mobile/features/editor/data/webview_document_editor_bridge.dart';
import 'package:gen_office_mobile/features/editor/presentation/mobile_docx_editor_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> waitFor(
    WidgetTester tester,
    Future<bool> Function() predicate,
  ) async {
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      if (await predicate()) return;
    }
    throw StateError('DOC editor did not become ready');
  }

  testWidgets(
    'one picker opens binary DOC, edits, saves binary DOC to original and reopens',
    (tester) async {
      final root = await (await getTemporaryDirectory()).createTemp(
        'legacy-doc-flow-',
      );
      addTearDown(() => root.delete(recursive: true));
      const converter = LegacyDocConverter();
      final data = await rootBundle.load(
        'assets/samples/legacy-conversion.docx',
      );
      var source = await converter.toDoc(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final original = Uint8List.fromList(source);
      const sourceUri = 'content://genoffice.test/legacy';
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidDocumentFiles.channel, (call) async {
            if (call.method == 'read') return source;
            if (call.method == 'write') {
              writes++;
              source = (call.arguments as Map)['bytes'] as Uint8List;
              return null;
            }
            throw StateError('unexpected source operation');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidDocumentFiles.channel, null),
      );
      final repository = LocalDocumentRepository(
        documentsDirectory: () async => root,
      );
      WebViewDocumentEditorBridge? bridge;
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentLibraryPage(
            dependencies: AppDependencies(
              documents: repository,
              ai: MockFactoryAiService(),
            ),
            recoveryStore: DocumentRecoveryStore(
              documentsDirectory: () async => root,
            ),
            pickDocument: () async =>
                SourceDocxFile(source, 'Nhà máy.DOC', sourceUri),
            onBridgeCreated: (value) => bridge = value,
          ),
        ),
      );
      await waitFor(
        tester,
        () async =>
            find.byKey(const Key('open-document')).evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(const Key('open-document')));
      await waitFor(tester, () async {
        if (bridge == null) return false;
        try {
          return await bridge!.controller.runJavaScriptReturningResult(
                '(document.querySelector(".ProseMirror[contenteditable=true]")?.textContent || "").includes("Xin chào nhà máy")',
              ) ==
              true;
        } catch (_) {
          return false;
        }
      });
      await tester.runAsync(() async {
        await bridge!.controller.runJavaScript('''
        (()=>{const p=document.querySelector('.ProseMirror p');p.closest('[contenteditable]').focus();
        const r=document.createRange();r.selectNodeContents(p);r.collapse(false);
        const s=window.getSelection();s.removeAllRanges();s.addRange(r);
        document.execCommand('insertText',false,' — sửa DOC ngoại tuyến');})();
      ''');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(await bridge!.hasUnsavedChanges(), isTrue);
        await bridge!.save();
      });
      await tester.pump();
      expect(writes, 1);
      expect(source.take(8), [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]);
      expect(source, isNot(equals(original)));
      final after = await converter.toDocx(source);
      final archive = ZipDecoder().decodeBytes(after);
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      // Decode UTF-8 rather than relying on a file extension or a successful Save ACK.
      expect(archive.findFile('word/document.xml'), isNotNull);
      expect(xml, contains('<w:tbl'));
      expect(xml, contains('sửa DOC ngoại tuyến'));
      final doc = (await repository.list()).single;
      expect(doc.name, 'Nhà máy.DOC');
      expect(doc.legacyDoc, isTrue);
      await tester.runAsync(
        () =>
            bridge!.hasUnsavedChanges().then((dirty) => expect(dirty, isFalse)),
      );
      await tester.pageBack();
      await waitFor(
        tester,
        () async =>
            find.byType(MobileDocxEditorPage).evaluate().isEmpty &&
            find.text('Nhà máy.DOC').evaluate().length == 1,
      );
      bridge = null;
      await tester.tap(find.text('Nhà máy.DOC'));
      await waitFor(tester, () async {
        if (bridge == null) return false;
        try {
          return (await bridge!.controller.runJavaScriptReturningResult(
            'document.querySelector(".ProseMirror")?.textContent || ""',
          )).toString().contains('sửa DOC ngoại tuyến');
        } catch (_) {
          return false;
        }
      });
      expect(find.byType(MobileDocxEditorPage), findsOneWidget);
      expect(writes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
