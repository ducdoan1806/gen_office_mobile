import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';
import 'package:gen_office_mobile/features/pdf/presentation/pdf_viewer_page.dart';
import 'package:gen_office_mobile/features/editor/presentation/mobile_docx_editor_page.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> waitFor(
    WidgetTester tester,
    Future<bool> Function() condition,
  ) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      if (await condition()) return;
    }
    throw StateError('PDF condition timed out');
  }

  testWidgets('editor open button dispatches PDF to the PDF viewer', (
    tester,
  ) async {
    final root = await (await getTemporaryDirectory()).createTemp(
      'pdf-dispatch-',
    );
    addTearDown(() => root.delete(recursive: true));
    final data = await rootBundle.load('assets/samples/pdf-viewer-test.pdf');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDocumentFiles.channel, (call) async {
          if (call.method == 'read') return bytes;
          throw StateError('PDF dispatch must not write');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidDocumentFiles.channel, null),
    );
    var ready = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDocxEditorPage(
          document: const OfficeDocument(
            id: 'dispatch-docx',
            name: 'source.docx',
            format: DocumentFormat.docx,
            assetPath: 'assets/samples/factory-demo.docx',
          ),
          documents: LocalDocumentRepository(
            documentsDirectory: () async => root,
          ),
          recoveryStore: DocumentRecoveryStore(
            documentsDirectory: () async => root,
          ),
          pickDocument: () async => SourceDocxFile(
            bytes,
            'selected.pdf',
            'content://test/pdf-dispatch',
          ),
          onReady: () => ready = true,
        ),
      ),
    );
    await waitFor(tester, () async => ready);
    await tester.pump();
    await tester.tap(find.byTooltip('Mở tài liệu'));
    await waitFor(
      tester,
      () async =>
          find.byType(PdfViewerPage).evaluate().isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    expect(find.byType(MobileDocxEditorPage), findsNothing);
    expect(find.textContaining('Không mở được PDF'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('PDF renders, navigates, searches and leaves source unchanged', (
    tester,
  ) async {
    final root = await (await getTemporaryDirectory()).createTemp('pdf-test-');
    addTearDown(() => root.delete(recursive: true));
    final data = await rootBundle.load('assets/samples/pdf-viewer-test.pdf');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final file = await File('${root.path}/safety.pdf').writeAsBytes(bytes);
    WebViewController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewerPage(
          document: OfficeDocument(
            id: 'pdf-fixture',
            name: 'safety.pdf',
            format: DocumentFormat.pdf,
            filePath: file.path,
          ),
          onControllerCreated: (value) => controller = value,
        ),
      ),
    );
    Future<bool> js(String expression) async =>
        controller != null &&
        await controller!.runJavaScriptReturningResult(expression) == true;
    await waitFor(
      tester,
      () => js(
        '!!document.querySelector(".page canvas") && !document.querySelector("#next").disabled',
      ),
    );
    await waitFor(
      tester,
      () async => find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    await controller!.runJavaScript('document.querySelector("#next").click()');
    await waitFor(
      tester,
      () => js('document.querySelector("#page").value === "2"'),
    );
    await controller!.runJavaScript(
      'document.querySelector("#page").value="3";document.querySelector("#page").dispatchEvent(new Event("change"))',
    );
    await waitFor(
      tester,
      () => js('document.querySelector("#page").value === "3"'),
    );
    await controller!.runJavaScript(
      'document.querySelector("#query").value="Machine inspection";document.querySelector("#searchForm").dispatchEvent(new Event("submit",{cancelable:true}))',
    );
    await waitFor(
      tester,
      () => js(
        'document.querySelector("#status").textContent.includes("1/1") && document.querySelector("#page").value === "2"',
      ),
    );
    await waitFor(
      tester,
      () => js('!!document.querySelector(".textLayer .highlight")'),
    );
    await controller!.runJavaScript(
      'document.querySelector("#query").value="Factory safety";document.querySelector("#searchForm").dispatchEvent(new Event("submit",{cancelable:true}))',
    );
    await waitFor(
      tester,
      () => js('document.querySelector("#status").textContent.includes("/3")'),
    );
    await controller!.runJavaScript(
      'document.querySelector("#findNext").click()',
    );
    await controller!.runJavaScript(
      'document.querySelector("#query").value="no-such-word-123";document.querySelector("#searchForm").dispatchEvent(new Event("submit",{cancelable:true}))',
    );
    await waitFor(
      tester,
      () => js(
        'document.querySelector("#status").textContent.includes("Không tìm thấy")',
      ),
    );
    expect(await file.readAsBytes(), bytes);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('corrupt PDF shows actionable error', (tester) async {
    final root = await (await getTemporaryDirectory()).createTemp(
      'bad-pdf-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    final file = await File(
      '${root.path}/bad.pdf',
    ).writeAsBytes(utf8.encode('%PDF-invalid'));
    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewerPage(
          document: OfficeDocument(
            id: 'bad',
            name: 'bad.pdf',
            format: DocumentFormat.pdf,
            filePath: file.path,
          ),
        ),
      ),
    );
    await waitFor(
      tester,
      () async =>
          find.textContaining('Không mở được PDF').evaluate().isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
