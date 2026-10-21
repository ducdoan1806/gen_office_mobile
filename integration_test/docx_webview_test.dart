import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gen_office_mobile/features/editor/data/webview_document_editor_bridge.dart';
import 'package:gen_office_mobile/features/editor/domain/editor_document.dart';
import 'package:gen_office_mobile/features/editor/presentation/mobile_docx_editor_page.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';
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
  // Keep editor regressions deterministic. The real SAF picker/provider is
  // exercised separately by Android SourceDocumentTest, including revocation.
  late Directory sourceDirectory;
  var sourceSequence = 0;
  var failSourceWrites = false;
  setUp(() async {
    failSourceWrites = false;
    sourceDirectory = await (await getTemporaryDirectory()).createTemp(
      'editor-source-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDocumentFiles.channel, (call) async {
          final args = call.arguments as Map?;
          if (call.method == 'open' || call.method == 'create') {
            final name = call.method == 'create'
                ? args!['name'] as String
                : 'linked-original.docx';
            final data = (await rootBundle.load(
              'assets/samples/factory-demo.docx',
            )).buffer.asUint8List();
            final file = File(
              '${sourceDirectory.path}/${++sourceSequence}.docx',
            );
            await file.writeAsBytes(data);
            return {'uri': file.uri.toString(), 'name': name, 'bytes': data};
          }
          final file = File.fromUri(Uri.parse(args!['uri'] as String));
          if (call.method == 'read') return file.readAsBytes();
          if (call.method == 'write') {
            if (failSourceWrites) {
              throw PlatformException(code: 'write_revoked');
            }
            await file.writeAsBytes(args['bytes'] as Uint8List, flush: true);
            expect(await file.readAsBytes(), args['bytes']);
            return null;
          }
          throw StateError('Unexpected source method');
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDocumentFiles.channel, null);
    await sourceDirectory.delete(recursive: true);
  });
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
            recoveryStore: DocumentRecoveryStore(
              documentsDirectory: () async => directory,
            ),
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
    late WebViewDocumentEditorBridge bridge;
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDocxEditorPage(
          document: imported,
          documents: repository(),
          recoveryStore: DocumentRecoveryStore(
            documentsDirectory: () async => libraryDirectory,
          ),
          onBridgeCreated: (value) => bridge = value,
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
      // Exercise the real ribbon commands on the selected paragraph, rather
      // than invoking formatting commands directly on the Tiptap instance.
      await bridge.controller.runJavaScript("""
        (() => {
        const paragraph = document.querySelector('.ProseMirror p');
        paragraph.closest('[contenteditable]').focus();
        const range = document.createRange(); range.selectNodeContents(paragraph);
        const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
        document.dispatchEvent(new Event('selectionchange'));
        })();
      """);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      for (final label in ['In nghiêng', 'Gạch chân', 'Căn giữa']) {
        await bridge.controller.runJavaScript(
          'document.querySelector(\'button[aria-label^="$label"]\').click()',
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      await bridge.controller.runJavaScript(
        "document.querySelector('.rb-font-size').closest('.rb-split-wrap').querySelector('button').click()",
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await bridge.controller.runJavaScript("""
        (() => {
        const option = [...document.querySelectorAll('.rb-font-size-menu button')].find(button => button.textContent.trim() === '18');
        if (!option) throw new Error('Font size 18 option is unavailable');
        option.click();
        })();
      """);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await bridge.controller.runJavaScript("""
        (() => {
        const cell = document.querySelector('.ProseMirror td p');
        cell.closest('[contenteditable]').focus();
        const range = document.createRange(); range.selectNodeContents(cell); range.collapse(false);
        const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
        document.execCommand('insertText', false, ' — ca sản xuất 2');
        })();
      """);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        (await bridge.controller.runJavaScriptReturningResult(
          "document.querySelector('.ProseMirror').textContent",
        )).toString(),
        contains('ca sản xuất 2'),
      );
      final touchTargets = await bridge.controller.runJavaScriptReturningResult(
        """
        [...document.querySelectorAll('button[aria-label^="In nghiêng"], button[aria-label^="Gạch chân"], button[aria-label^="Căn giữa"]')]
          .every(button => { const box = button.getBoundingClientRect(); return box.width >= 44 && box.height >= 44; })
      """,
      );
      expect(touchTargets, true);
      await bridge.controller.runJavaScript("""
        (() => {
          const paragraph = document.querySelector('.ProseMirror p');
          paragraph.closest('[contenteditable]').focus();
          const range = document.createRange(); range.selectNodeContents(paragraph); range.collapse(false);
          const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
          document.execCommand('insertParagraph');
          document.execCommand('insertText', false, 'Biểu mẫu ca mới');
          [...document.querySelectorAll('.ribbon-tab')].find(button => button.textContent.trim() === 'Chèn').click();
        })();
      """);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await bridge.controller.runJavaScript(
        "document.querySelector('button[data-tip=\"Chèn bảng\"]').click()",
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final gridTarget = await bridge.controller.runJavaScriptReturningResult(
        """
        (() => { const box = document.querySelector('.table-cell[data-rows="2"][data-columns="2"]').getBoundingClientRect(); return box.width >= 44 && box.height >= 44; })()
      """,
      );
      expect(gridTarget, true);
      await bridge.controller.runJavaScript(
        "document.querySelector('.table-cell[data-rows=\"2\"][data-columns=\"2\"]').click()",
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final tableCount = await bridge.controller.runJavaScriptReturningResult(
        "document.querySelectorAll('.ProseMirror table').length",
      );
      expect(tableCount, 2);
      expect(
        (await bridge.controller.runJavaScriptReturningResult(
          "document.querySelector('.ProseMirror').textContent",
        )).toString(),
        contains('ca sản xuất 2'),
      );
      final result = await bridge.save();
      final restored = await repository().list();
      expect(restored, hasLength(1));
      expect(restored.single.id, imported.id);
      expect(
        restored.any((document) => document.filePath == result.path),
        true,
      );
      expect(await File(result.path).exists(), true);
      final bytes = await File(result.path).readAsBytes();
      expect(bytes.length, greaterThan(100));
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      expect(xml, contains('ca sản xuất 2'));
      expect(xml, contains('Biểu mẫu ca mới'));
      expect(xml, matches(RegExp(r'<w:i(?:\s|/|>)')));
      expect(xml, matches(RegExp(r'<w:u\b')));
      expect(xml, matches(RegExp(r'<w:jc\b[^>]*w:val="center"')));
      expect(xml, matches(RegExp(r'<w:sz\b[^>]*w:val="36"')));
      expect(RegExp(r'<w:tbl[\s>]').allMatches(xml), hasLength(2));
      final sourceArchive = ZipDecoder().decodeBytes(originalBytes);
      for (final entry in sourceArchive.files.where(
        (file) => file.name.startsWith('customXml/'),
      )) {
        expect(archive.findFile(entry.name)?.content, entry.content);
      }
      await bridge.open(
        EditorDocument(id: 'reopened', name: result.name, bytes: bytes),
      );
      final text = await bridge.controller.runJavaScriptReturningResult(
        "document.querySelector('.ProseMirror').textContent",
      );
      expect(text.toString(), contains('kiểm thử mobile'));
      expect(text.toString(), contains('ca sản xuất 2'));
      expect(text.toString(), contains('Biểu mẫu ca mới'));
      expect(
        await bridge.controller.runJavaScriptReturningResult(
          "document.querySelectorAll('.ProseMirror table').length",
        ),
        2,
      );
      final formatting = await bridge.controller.runJavaScriptReturningResult(
        """
        (() => {
          const paragraph = document.querySelector('.ProseMirror p');
          return getComputedStyle(paragraph).textAlign === 'center'
            && paragraph.querySelector('em, i, [style*="italic"]') !== null
            && paragraph.querySelector('u, [style*="underline"]') !== null;
        })()
      """,
      );
      expect(formatting, true);
      expect(bridge.error.value, isNull);
      final secondSave = await bridge.save();
      final afterSecondSave = await repository().list();
      expect(afterSecondSave, hasLength(1));
      expect(afterSecondSave.single.id, imported.id);
      expect(afterSecondSave.single.filePath, secondSave.path);
      expect(await File(secondSave.path).readAsBytes(), isNotEmpty);
      final sourceUri = afterSecondSave.single.sourceUri!;
      final savedSource = await const AndroidDocumentFiles().read(sourceUri);
      expect(savedSource, await File(secondSave.path).readAsBytes());
      await bridge.controller.runJavaScript("""
        const p=document.querySelector('.ProseMirror p');
        const r=document.createRange();r.selectNodeContents(p);r.collapse(false);
        const s=window.getSelection();s.removeAllRanges();s.addRange(r);
        document.querySelector('.ProseMirror').focus();
        document.execCommand('insertText',false,' — unsaved permission test');
      """);
      expect(await bridge.hasUnsavedChanges(), true);
      failSourceWrites = true;
      await expectLater(bridge.save(), throwsA(anything));
      expect(await bridge.hasUnsavedChanges(), true);
      expect(await const AndroidDocumentFiles().read(sourceUri), savedSource);
      failSourceWrites = false;
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'Save follows the document opened inside the editor and Save As stays separate',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'save-current-docx-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final sample = await rootBundle.load('assets/samples/factory-demo.docx');
      final sourceBytes = sample.buffer.asUint8List(
        sample.offsetInBytes,
        sample.lengthInBytes,
      );
      final secondSource = File('${directory.path}/second.docx');
      await secondSource.writeAsBytes(sourceBytes);
      final repository = LocalDocumentRepository(
        documentsDirectory: () async => directory,
      );
      final first = await repository.storeDocx('first.docx', sourceBytes);
      late WebViewDocumentEditorBridge bridge;
      var ready = false;
      var picks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MobileDocxEditorPage(
            document: first,
            documents: repository,
            recoveryStore: DocumentRecoveryStore(
              documentsDirectory: () async => directory,
            ),
            onBridgeCreated: (value) => bridge = value,
            onReady: () => ready = true,
            pickDocument: () async {
              picks++;
              return XFile(secondSource.path);
            },
          ),
        ),
      );
      await pumpUntil(tester, () => ready);
      Future<void> append(String text) async {
        await bridge.controller.runJavaScript('''
        (() => {
          const paragraph = document.querySelector('.ProseMirror p');
          paragraph.closest('[contenteditable]').focus();
          const range = document.createRange(); range.selectNodeContents(paragraph); range.collapse(false);
          const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
          document.execCommand('insertText', false, ${jsonEncode(text)});
        })();
      ''');
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      await tester.runAsync(() async {
        await append(' — bản A');
        await bridge.save();
        expect(await bridge.hasUnsavedChanges(), false);
      });
      final savedA = (await repository.list()).single;
      expect(savedA.id, first.id);
      final aBytes = await File(savedA.filePath!).readAsBytes();
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-docx')));
      await pumpUntil(tester, () => picks == 1);
      await pumpUntil(
        tester,
        () =>
            find.byType(AlertDialog).evaluate().isNotEmpty ||
            find.textContaining('Lỗi:').evaluate().isNotEmpty ||
            (find.text('second.docx').evaluate().isNotEmpty &&
                tester
                        .widget<IconButton>(find.byKey(const Key('save-docx')))
                        .onPressed !=
                    null),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Lỗi:'), findsNothing);
      await tester.runAsync(() async {
        await append(' — bản B');
        await bridge.save();
        await bridge.save();
      });
      final documents = await repository.list();
      expect(documents, hasLength(2));
      final bDocument = documents.singleWhere(
        (document) => document.name == 'second.docx',
      );
      final aDocument = documents.singleWhere(
        (document) => document.id == first.id,
      );
      expect(await File(aDocument.filePath!).readAsBytes(), aBytes);
      expect(await secondSource.readAsBytes(), sourceBytes);
      final bZip = ZipDecoder().decodeBytes(
        await File(bDocument.filePath!).readAsBytes(),
      );
      final bXml = utf8.decode(
        bZip.findFile('word/document.xml')!.content as List<int>,
      );
      expect(bXml, contains('bản B'));
      expect(bXml, isNot(contains('bản A')));
      await tester.runAsync(() async {
        final copied = bridge.server.saved.first;
        await bridge.controller.runJavaScript(
          'window.desktop.saveDocxAs("copy.docx",new Uint8Array(${jsonEncode(sourceBytes)}).buffer)',
        );
        await copied.timeout(const Duration(seconds: 15));
        expect(await repository.list(), hasLength(3));
        await bridge.save();
        final afterCopySave = await repository.list();
        expect(afterCopySave, hasLength(3));
        expect(
          afterCopySave.where((document) => document.name == 'copy.docx'),
          hasLength(1),
        );
        expect(await File(aDocument.filePath!).readAsBytes(), aBytes);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'corrupt recovery requires explicit discard before opening original',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'corrupt-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = LocalDocumentRepository(
        documentsDirectory: () async => directory,
      );
      final recovery = DocumentRecoveryStore(
        documentsDirectory: () async => directory,
      );
      final original = (await rootBundle.load(
        'assets/samples/factory-demo.docx',
      )).buffer.asUint8List();
      final document = await repository.storeDocx(
        'corrupt-recovery.docx',
        original,
      );
      await recovery.write(
        document,
        original,
        baseHash: DocumentRecoveryStore.hash(original),
      );
      final snapshot = (await recovery.find(document.id))!;
      final metadata = File(
        '${File(snapshot.contentPath).parent.path}/snapshot.json',
      );
      await metadata.writeAsString('{"version":999}', flush: true);
      var ready = false;
      late WebViewDocumentEditorBridge bridge;
      await tester.pumpWidget(
        MaterialApp(
          home: MobileDocxEditorPage(
            document: document,
            documents: repository,
            recoveryStore: recovery,
            onReady: () => ready = true,
            onBridgeCreated: (value) => bridge = value,
          ),
        ),
      );
      await pumpUntil(
        tester,
        () => find.text('Không đọc được bản tạm').evaluate().isNotEmpty,
      );
      expect(await metadata.exists(), true);
      await tester.tap(find.text('Bỏ bản tạm, mở gốc'));
      await pumpUntil(tester, () => ready);
      await tester.runAsync(() async {
        expect(await bridge.hasUnsavedChanges(), false);
        expect(await recovery.list(), isEmpty);
        expect(await File(document.filePath!).readAsBytes(), original);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
