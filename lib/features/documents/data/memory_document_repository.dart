import 'dart:typed_data';
import '../domain/document_repository.dart';
import '../domain/office_document.dart';

/// Demo fixtures for tests; the app uses LocalDocumentRepository.
class MemoryDocumentRepository implements DocumentRepository {
  @override
  Future<OfficeDocument> storePdf(
    String name,
    Uint8List bytes, {
    String? sourceUri,
  }) async =>
      throw UnsupportedError('Demo repository does not persist documents.');
  @override
  Future<OfficeDocument> updateDocx(
    String id,
    Uint8List bytes, {
    String? sourceUri,
  }) async =>
      throw UnsupportedError('Demo repository does not persist documents.');
  @override
  Future<OfficeDocument> storeDocx(
    String name,
    Uint8List bytes, {
    bool isExport = false,
    String? sourceUri,
  }) async =>
      throw UnsupportedError('Demo repository does not persist documents.');
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
      assetPath: 'assets/samples/pdf-viewer-test.pdf',
    ),
  ];
}
