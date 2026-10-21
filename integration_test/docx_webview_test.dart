import 'dart:async';
import 'dart:io';
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
