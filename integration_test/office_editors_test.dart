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
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';
import 'package:gen_office_mobile/features/documents/presentation/document_library_page.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';
import 'package:gen_office_mobile/features/editor/data/webview_document_editor_bridge.dart';
import 'package:gen_office_mobile/features/editor/presentation/mobile_docx_editor_page.dart';
import 'factory_docx_test.dart' show withFrames;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> until(
    WidgetTester tester,
    Future<bool> Function() condition,
  ) async {
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      if (await condition()) return;
    }
    throw StateError('Office integration condition timed out');
  }

  for (final format in [DocumentFormat.xlsx, DocumentFormat.pptx]) {
    testWidgets(
      '${format.name}: one picker, real edit, undo, recovery, original save and reopen',
      (tester) async {
        final root = await (await getTemporaryDirectory()).createTemp(
          'office-qa-',
        );
        addTearDown(() => root.delete(recursive: true));
        final bundle = await rootBundle.load(
          'assets/samples/${format == DocumentFormat.xlsx ? 'sheets-test.xlsx' : 'slides-test.pptx'}',
        );
        var source = bundle.buffer.asUint8List(
          bundle.offsetInBytes,
          bundle.lengthInBytes,
        );
        final original = Uint8List.fromList(source);
        var writes = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidDocumentFiles.channel, (
              call,
            ) async {
              if (call.method == 'read') return source;
              if (call.method == 'write') {
                source = (call.arguments as Map)['bytes'] as Uint8List;
                writes++;
                return null;
              }
              throw StateError('Unexpected file call');
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(AndroidDocumentFiles.channel, null),
        );
        final repo = LocalDocumentRepository(
          documentsDirectory: () async => root,
        );
        final recovery = DocumentRecoveryStore(
          documentsDirectory: () async => root,
        );
        WebViewDocumentEditorBridge? bridge;
        await tester.pumpWidget(
          MaterialApp(
            home: DocumentLibraryPage(
              dependencies: AppDependencies(
                documents: repo,
                ai: MockFactoryAiService(),
              ),
              recoveryStore: recovery,
              onBridgeCreated: (v) => bridge = v,
              pickDocument: () async => SourceDocxFile(
                source,
                'Nhà máy.${format.name}',
                'content://office/${format.name}',
              ),
            ),
          ),
        );
        await until(
          tester,
          () async =>
              find.byKey(const Key('open-document')).evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(const Key('open-document')));
        Future<bool> js(String expression) async =>
            bridge != null &&
            await bridge!.controller.runJavaScriptReturningResult(expression) ==
                true;
        await until(
          tester,
          () => js(
            format == DocumentFormat.xlsx
                ? '!!window.genOfficeSheets?.getActiveWorkbook()'
                : 'document.querySelectorAll("[data-paragraph]").length>0',
          ),
        );
        if (format == DocumentFormat.xlsx) {
          await bridge!.controller.runJavaScript(
            'window.genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange("B2").setValue(25)',
          );
          await until(
            tester,
            () => js(
              'window.genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange("D2").getValue()===33',
            ),
          );
        } else {
          await until(
            tester,
            () => js('!!document.querySelector("#slide-canvas canvas")'),
          );
          await bridge!.controller.runJavaScript(
            'const input=document.querySelectorAll("[data-paragraph]")[0];input.value="Báo cáo đã sửa tiếng Việt";input.dispatchEvent(new Event("input"));',
          );
        }
        expect(
          await withFrames(tester, () => bridge!.hasUnsavedChanges()),
          true,
        );
        await withFrames(tester, () => bridge!.undo());
        expect(
          await withFrames(tester, () => bridge!.hasUnsavedChanges()),
          false,
        );
        await withFrames(tester, () => bridge!.redo());
        expect(
          await withFrames(tester, () => bridge!.hasUnsavedChanges()),
          true,
        );
        await until(tester, () async => (await recovery.list()).isNotEmpty);
        final draft = (await recovery.list()).single;
        expect(draft.document.format, format);
        expect(source, original);
        await withFrames(tester, () => bridge!.save());
        expect(writes, 1);
        expect(await recovery.list(), isEmpty);
        expect(await repo.list(), hasLength(1));
        final zip = ZipDecoder().decodeBytes(source);
        final before = ZipDecoder().decodeBytes(original);
        final editedPart = format == DocumentFormat.xlsx
            ? 'xl/worksheets/sheet1.xml'
            : 'ppt/slides/slide1.xml';
        final content = utf8.decode(
          zip.findFile(editedPart)!.content as List<int>,
        );
        expect(
          content,
          contains(
            format == DocumentFormat.xlsx
                ? '>25<'
                : 'Báo cáo đã sửa tiếng Việt',
          ),
        );
        for (final file in before.files.where(
          (e) =>
              e.isFile &&
              (format == DocumentFormat.xlsx
                  ? e.name.startsWith('xl/charts/') ||
                        e.name.startsWith('xl/media/')
                  : e.name.startsWith('ppt/media/') ||
                        e.name.startsWith('ppt/notesSlides/')),
        )) {
          expect(
            zip.findFile(file.name)!.content,
            file.content,
            reason: 'Preserve ${file.name}',
          );
        }
        await tester.pageBack();
        await until(
          tester,
          () async => find.byType(MobileDocxEditorPage).evaluate().isEmpty,
        );
        await tester.tap(find.text('Nhà máy.${format.name}'));
        await until(
          tester,
          () => js(
            format == DocumentFormat.xlsx
                ? 'window.genOfficeSheets?.getActiveWorkbook()?.getSheets()[0].getRange("B2").getValue()===25'
                : 'document.querySelectorAll("[data-paragraph]")[0]?.value==="Báo cáo đã sửa tiếng Việt"',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
