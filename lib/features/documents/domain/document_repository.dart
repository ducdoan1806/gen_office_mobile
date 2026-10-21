import 'dart:typed_data';
import 'office_document.dart';

abstract interface class DocumentRepository {
  Future<List<OfficeDocument>> list();
  Future<OfficeDocument> updateDocx(String id, Uint8List bytes);
  Future<OfficeDocument> storeDocx(
    String name,
    Uint8List bytes, {
    bool isExport = false,
  });
}
