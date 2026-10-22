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
    expect(find.byType(LinearProgressIndicator), findsNothing);
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
