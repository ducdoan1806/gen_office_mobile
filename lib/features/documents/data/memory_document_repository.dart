import '../domain/document_repository.dart';
import '../domain/office_document.dart';

/// Demo metadata only. Replace with file picker and persistent local storage.
class MemoryDocumentRepository implements DocumentRepository {
  @override
  Future<List<OfficeDocument>> list() async => const [
    OfficeDocument(
      id: 'demo-doc',
      name: 'Quy trình vận hành.docx',
      format: DocumentFormat.docx,
      assetPath: 'assets/samples/factory-demo.docx',
    ),
    OfficeDocument(
      id: 'demo-sheet',
      name: 'Kế hoạch sản xuất.xlsx',
      format: DocumentFormat.xlsx,
    ),
    OfficeDocument(
      id: 'demo-pdf',
      name: 'Hướng dẫn an toàn.pdf',
      format: DocumentFormat.pdf,
    ),
  ];
}
