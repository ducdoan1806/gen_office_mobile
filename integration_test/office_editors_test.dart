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
import 'package:gen_office_mobile/features/documents/data/legacy_doc_converter.dart';
import 'package:gen_office_mobile/features/documents/data/csv_workbook_codec.dart';
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
      if (await tester.runAsync(condition) == true) return;
    }
    throw StateError('Office integration condition timed out');
  }

  for (final extension in ['xlsx', 'pptx', 'xls', 'ppt', 'csv']) {
    final format = extension == 'ppt' || extension == 'pptx'
        ? DocumentFormat.pptx
        : DocumentFormat.xlsx;
    final converted = extension != format.name;
    testWidgets(
      '$extension: one picker, real edit, undo, recovery, original save and reopen',
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
        if (extension == 'csv') {
          source = Uint8List.fromList(
            utf8.encode(
              'Mặt hàng;Số lượng;Bổ sung;Tổng\r\nSản phẩm A;12;8;20\r\n',
            ),
          );
        } else if (converted) {
          source = await withFrames(
            tester,
            () => const LegacyDocConverter().convertOffice(
              source,
              format.name,
              extension,
            ),
          );
        }
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
                'Nhà máy.$extension',
                'content://office/$extension',
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
        Future<void> execute(String script) =>
            withFrames(tester, () => bridge!.controller.runJavaScript(script));
        Future<bool> js(String expression) async =>
            bridge != null &&
            await bridge!.controller.runJavaScriptReturningResult(expression) ==
                true;
        await until(
          tester,
          () => js(
            format == DocumentFormat.xlsx
                ? '!!window.genOfficeSheets?.getActiveWorkbook()'
                : 'document.querySelectorAll(".konvajs-content canvas").length>0',
          ),
        );
        await until(
          tester,
          () async => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        debugPrint('OFFICE QA: opened ${format.name}');
        if (format == DocumentFormat.xlsx) {
          if (extension == 'csv') {
            await execute(
              'window.genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange("D2").setValue("=SUM(B2:C2)")',
            );
          }
          await execute(
            'window.genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange("B2").setValue(25)',
          );
          await until(
            tester,
            () => js(
              'window.genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange("D2").getValue()===33',
            ),
          );
        } else {
          await execute('''(async()=>{
              const tree=(await window.slidesApi.getRenderSlides())[0];
              const node=tree.nodes.find(n=>n.text && n.box.w>50 && n.box.h>10 && n.text.lines.some(l=>l.runs.some(r=>r.text.trim())));
              const content=[...document.querySelectorAll('.konvajs-content')].at(-1);
              const box=content.getBoundingClientRect(),scale=box.width/(tree.widthPx+320);
              const clientX=box.x+(node.box.x+160+node.box.w/2)*scale;
              const clientY=box.y+(node.box.y+160+node.box.h/2)*scale;
              for(let i=0;i<2;i++)for(const type of ['mousedown','mouseup'])content.dispatchEvent(new MouseEvent(type,{bubbles:true,clientX,clientY,button:0}));
            })()''');
          await until(
            tester,
            () => js('!!document.querySelector(".slide-text-editor")'),
          );
          await execute(
            '''const input=document.querySelector('.slide-text-editor');input.focus();input.innerText='Báo cáo đã sửa tiếng Việt';input.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText'}));input.blur();''',
          );
          await until(
            tester,
            () => js('!document.querySelector(".slide-text-editor")'),
          );
        }
        expect(
          await withFrames(tester, () => bridge!.hasUnsavedChanges()),
          true,
        );
        debugPrint('OFFICE QA: edited ${format.name}');
        await withFrames(tester, () => bridge!.undo());
        if (format == DocumentFormat.xlsx) {
          await until(
            tester,
            () => js(
              'window.genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange("B2").getValue()===12',
            ),
          );
        } else {
          await execute(
            'window.slidesApi.getRenderSlides().then(slides=>window.officeQaText=slides.flatMap(s=>s.nodes).filter(n=>n.text).flatMap(n=>n.text.lines).flatMap(l=>l.runs).map(r=>r.text).join("").replace(/\\s+/g,""))',
          );
          await until(
            tester,
            () => js(
              'typeof window.officeQaText==="string" && !window.officeQaText.includes("BáocáođãsửatiếngViệt")',
            ),
          );
        }
        await withFrames(tester, () => bridge!.redo());
        if (format == DocumentFormat.xlsx) {
          await until(
            tester,
            () => js(
              'window.genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange("B2").getValue()===25',
            ),
          );
        } else {
          await execute(
            'window.slidesApi.getRenderSlides().then(slides=>window.officeQaText=slides.flatMap(s=>s.nodes).filter(n=>n.text).flatMap(n=>n.text.lines).flatMap(l=>l.runs).map(r=>r.text).join("").replace(/\\s+/g,""))',
          );
          await until(
            tester,
            () => js('window.officeQaText.includes("BáocáođãsửatiếngViệt")'),
          );
        }
        expect(
          await withFrames(tester, () => bridge!.hasUnsavedChanges()),
          true,
        );
        await until(tester, () async => (await recovery.list()).isNotEmpty);
        final draft = (await recovery.list()).single;
        expect(draft.document.format, format);
        expect(source, original);
        if (extension == 'csv') {
          Future<dynamic>? saving;
          await tester.runAsync(() async {
            saving = bridge!.save();
          });
          await until(
            tester,
            () async => find.text('Lưu CSV').evaluate().isNotEmpty,
          );
          await tester.tap(find.text('Lưu CSV'));
          await withFrames(tester, () => saving!);
        } else {
          await withFrames(tester, () => bridge!.save());
        }
        expect(writes, 1);
        expect(await recovery.list(), isEmpty);
        expect(await repo.list(), hasLength(1));
        final modern = extension == 'csv'
            ? CsvWorkbookCodec.toXlsx(source)
            : converted
            ? await withFrames(
                tester,
                () => const LegacyDocConverter().convertOffice(
                  source,
                  extension,
                  format.name,
                ),
              )
            : source;
        if (converted && extension != 'csv') {
          expect(source.take(8), [208, 207, 17, 224, 161, 177, 26, 225]);
        }
        final zip = ZipDecoder().decodeBytes(modern);
        final before = converted ? null : ZipDecoder().decodeBytes(original);
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
        for (final file in (before?.files ?? <ArchiveFile>[]).where(
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
        await tester.tap(find.text('Nhà máy.$extension'));
        await until(
          tester,
          () => js(
            format == DocumentFormat.xlsx
                ? 'window.genOfficeSheets?.getActiveWorkbook()?.getSheets()[0].getRange("B2").getValue()===25'
                : '!!document.querySelector(".konvajs-content canvas")',
          ),
        );
        if (format == DocumentFormat.pptx) {
          await until(
            tester,
            () async => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await execute(
            'window.slidesApi.getRenderSlides().then(slides=>window.officeQaText=slides.flatMap(s=>s.nodes).filter(n=>n.text).flatMap(n=>n.text.lines).flatMap(l=>l.runs).map(r=>r.text).join("").replace(/\\s+/g,""))',
          );
          await until(
            tester,
            () => js('window.officeQaText.includes("BáocáođãsửatiếngViệt")'),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
