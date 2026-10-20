import 'office_document.dart';

abstract interface class DocumentRepository {
  Future<List<OfficeDocument>> list();
}
