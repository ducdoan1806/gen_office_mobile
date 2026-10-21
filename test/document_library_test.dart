import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/app/app.dart';
import 'package:gen_office_mobile/app/dependencies.dart';
import 'package:gen_office_mobile/features/ai/data/mock_factory_ai_service.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/presentation/document_library_page.dart';

void main() {
  testWidgets('import opens the editor and returning refreshes the library', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('genoffice-import-ui-'),
    ))!;
    addTearDown(() => directory.delete(recursive: true));
    final repository = LocalDocumentRepository(
      documentsDirectory: () async => directory,
    );
    final source = File('${directory.path}/test.docx');
    await tester.runAsync(() => source.writeAsBytes([80, 75, 3, 4]));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentLibraryPage(
            dependencies: AppDependencies(
              documents: repository,
              ai: MockFactoryAiService(),
            ),
            pickDocument: () async => XFile(source.path),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('import-docx')));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Host widget tests cannot create Android WebView, but must reach its page.
    expect(find.byKey(const Key('save-docx')), findsOneWidget);
    expect(find.textContaining('Không nhập được DOCX'), findsNothing);
    await tester.runAsync(() async {
      await tester.pageBack();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('test.docx'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Tải lại'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('test.docx'), findsOneWidget);
    final stored = (await tester.runAsync(repository.list))!;
    expect(stored, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'library shows stored documents after a fresh app and repository',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('genoffice-library-ui-'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      LocalDocumentRepository repository() =>
          LocalDocumentRepository(documentsDirectory: () async => directory);
      Widget app() => GenOfficeApp(
        dependencies: AppDependencies(
          documents: repository(),
          ai: MockFactoryAiService(),
        ),
      );

      Future<void> showLibrary() async {
        await tester.runAsync(() async {
          await tester.pumpWidget(app());
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
      }

      await showLibrary();
      expect(
        find.text('Chưa có tài liệu. Nhấn “Nhập DOCX” để thêm.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('import-docx')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => repository().storeDocx(
          'Quy trình nhà máy.docx',
          Uint8List.fromList([80, 75, 3, 4]),
        ),
      );
      await showLibrary();
      expect(find.text('Quy trình nhà máy.docx'), findsOneWidget);
      expect(find.textContaining('KB'), findsOneWidget);
      expect(find.text('Quy trình vận hành.docx'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await showLibrary();
      expect(find.text('Quy trình nhà máy.docx'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
