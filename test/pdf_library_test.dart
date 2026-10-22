import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/app/dependencies.dart';
import 'package:gen_office_mobile/features/ai/data/mock_factory_ai_service.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/documents/data/memory_document_repository.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';
import 'package:gen_office_mobile/features/documents/presentation/document_library_page.dart';
import 'package:gen_office_mobile/features/pdf/presentation/pdf_viewer_page.dart';

class PdfLibrary extends MemoryDocumentRepository {
  final documents = <OfficeDocument>[];
  @override
  Future<List<OfficeDocument>> list() async => documents;
  @override
  Future<OfficeDocument> storePdf(
    String name,
    Uint8List bytes, {
    String? sourceUri,
  }) async {
    final document = OfficeDocument(
      id: 'pdf',
      name: name,
      format: DocumentFormat.pdf,
      sourceUri: sourceUri,
    );
    documents.add(document);
    return document;
  }
}

void main() {
  testWidgets('PDF import and recent entry open the reader', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = PdfLibrary();
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentLibraryPage(
          dependencies: AppDependencies(
            documents: repository,
            ai: MockFactoryAiService(),
          ),
          pickDocument: () async => SourceDocxFile(
            Uint8List.fromList([37, 80, 68, 70, 45]),
            'Safety.pdf',
            'content://test/pdf',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mở tài liệu'), findsOneWidget);
    expect(find.text('Mở PDF'), findsNothing);
    expect(find.text('Mở DOCX'), findsNothing);
    await tester.tap(find.byKey(const Key('open-document')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PdfViewerPage), findsOneWidget);
    expect(find.byKey(const Key('save-docx')), findsNothing);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Safety.pdf'), findsOneWidget);
    expect(repository.documents.single.sourceUri, 'content://test/pdf');
    await tester.tap(find.text('Safety.pdf'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PdfViewerPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
