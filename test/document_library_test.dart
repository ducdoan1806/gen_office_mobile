import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/app/app.dart';
import 'package:gen_office_mobile/app/dependencies.dart';
import 'package:gen_office_mobile/features/ai/data/mock_factory_ai_service.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';

void main() {
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
