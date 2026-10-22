import 'dart:typed_data';
import 'office_document.dart';

abstract interface class DocumentRepository {
  Future<List<OfficeDocument>> list();
  Future<OfficeDocument> storeOffice(
    String name,
    Uint8List bytes, {
    required DocumentFormat format,
    bool isExport = false,
    bool legacyDoc = false,
    String? sourceUri,
  });
  Future<OfficeDocument> updateOffice(
    String id,
    Uint8List bytes, {
    String? sourceUri,
  });

  Future<OfficeDocument> storePdf(
    String name,
    Uint8List bytes, {
    String? sourceUri,
  });
  Future<OfficeDocument> updateDocx(
    String id,
    Uint8List bytes, {
    String? sourceUri,
  });
  Future<OfficeDocument> storeDocx(
    String name,
    Uint8List bytes, {
    bool isExport = false,
    bool legacyDoc = false,
    String? sourceUri,
  });
}
