import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gen_office_mobile/features/editor/data/editor_asset_server.dart';
import 'package:gen_office_mobile/features/editor/data/webview_document_editor_bridge.dart';
import 'package:gen_office_mobile/features/editor/domain/editor_document.dart';
import 'package:gen_office_mobile/features/editor/presentation/mobile_docx_editor_page.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/presentation/document_library_page.dart';
import 'package:gen_office_mobile/app/dependencies.dart';
import 'package:gen_office_mobile/features/ai/data/mock_factory_ai_service.dart';

Future<void> pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var attempt = 0; attempt < 450; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    if (predicate()) return;
  }
  throw StateError('Editor did not become ready');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'library import opens native WebView and refreshes after returning',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'genoffice-import-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final sample = await rootBundle.load('assets/samples/factory-demo.docx');
      final source = File('${directory.path}/native-import.docx');
      await source.writeAsBytes(
        sample.buffer.asUint8List(sample.offsetInBytes, sample.lengthInBytes),
      );
      final repository = LocalDocumentRepository(
        documentsDirectory: () async => directory,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentLibraryPage(
            dependencies: AppDependencies(
              documents: repository,
              ai: MockFactoryAiService(),
            ),
            // Supply only the picker result; import, navigation and WebView are real.
            pickDocument: () async => XFile(source.path),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-docx')));
      await pumpUntil(tester, () {
        final save = find.byKey(const Key('save-docx'));
        return save.evaluate().isNotEmpty &&
            tester.widget<IconButton>(save).onPressed != null;
      });
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.textContaining('Không nhập được DOCX'), findsNothing);
      final imported = (await repository.list()).single;
      expect(imported.name, 'native-import.docx');
      expect(
        await File(imported.filePath!).readAsBytes(),
        await source.readAsBytes(),
      );
      await tester.pageBack();
      await pumpUntil(
        tester,
        () =>
            find.byKey(const Key('import-docx')).evaluate().isNotEmpty &&
            find.byType(WebViewWidget).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tải lại'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('native-import.docx'), findsOneWidget);
      expect(await repository.list(), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets('native WebView opens, edits, saves and reopens DOCX', (
    tester,
  ) async {
    final loaded = Completer<void>();
    final directory = await getTemporaryDirectory();
    final libraryDirectory = await directory.createTemp(
      'genoffice-library-test-',
    );
    addTearDown(() => libraryDirectory.delete(recursive: true));
    LocalDocumentRepository repository() => LocalDocumentRepository(
      documentsDirectory: () async => libraryDirectory,
    );
    final originalBytes = (await rootBundle.load(
      'assets/samples/factory-demo.docx',
    )).buffer.asUint8List();
    await repository().storeDocx('factory-demo.docx', originalBytes);
    final imported = (await repository().list()).single;
    final bridge = WebViewDocumentEditorBridge(
      server: EditorAssetServer(
        persistExport: (name, bytes) async {
          final saved = await repository().storeDocx(
            name,
            bytes,
            isExport: true,
          );
          return EditorSaveResult(name: saved.name, path: saved.filePath!);
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDocxEditorPage(
          document: imported,
          documents: repository(),
          bridge: bridge,
          onReady: () {
            if (!loaded.isCompleted) loaded.complete();
          },
        ),
      ),
    );
    await pumpUntil(tester, () => loaded.isCompleted);
    expect(find.byType(WebViewWidget), findsOneWidget);
    await tester.runAsync(() async {
      expect(await bridge.hasUnsavedChanges(), false);
      await bridge.controller.runJavaScript("""
    const editor=document.querySelector('.ProseMirror[contenteditable="true"]');
    const paragraph=editor.querySelector('p');editor.focus();
    const range=document.createRange();range.selectNodeContents(paragraph);range.collapse(false);
    const selection=window.getSelection();selection.removeAllRanges();selection.addRange(range);
    document.execCommand('insertText',false,' — kiểm thử mobile');
   """);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(await bridge.hasUnsavedChanges(), true);
      await bridge.undo();
      final undone = await bridge.controller.runJavaScriptReturningResult(
        "document.querySelector('.ProseMirror').textContent",
      );
      expect(undone.toString(), isNot(contains('kiểm thử mobile')));
      await bridge.redo();
      expect(await bridge.hasUnsavedChanges(), true);
      final result = await bridge.save();
      final restored = await repository().list();
      expect(restored, hasLength(2));
      expect(
        restored.any((document) => document.filePath == result.path),
        true,
      );
      expect(await File(imported.filePath!).readAsBytes(), originalBytes);
      expect(await File(result.path).exists(), true);
      final bytes = await File(result.path).readAsBytes();
      expect(bytes.length, greaterThan(100));
      await bridge.open(
        EditorDocument(id: 'reopened', name: result.name, bytes: bytes),
      );
      final text = await bridge.controller.runJavaScriptReturningResult(
        "document.querySelector('.ProseMirror').textContent",
      );
      expect(text.toString(), contains('kiểm thử mobile'));
      expect(bridge.error.value, isNull);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
