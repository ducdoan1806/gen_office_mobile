import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';

void main() {
  test(
    'PDF persists alongside DOCX, dedupes URI and cannot be overwritten as DOCX',
    () async {
      final root = await Directory.systemTemp.createTemp('pdf-repository-');
      addTearDown(() => root.delete(recursive: true));
      LocalDocumentRepository repository() =>
          LocalDocumentRepository(documentsDirectory: () async => root);
      final bytes = await File(
        'assets/samples/pdf-viewer-test.pdf',
      ).readAsBytes();
      final pdf = await repository().storePdf(
        '../Safety.PDF',
        bytes,
        sourceUri: 'content://test/pdf',
      );
      final same = await repository().storePdf(
        'Safety.PDF',
        bytes,
        sourceUri: 'content://test/pdf',
      );
      expect(same.id, pdf.id);
      await repository().storeDocx(
        'test.docx',
        Uint8List.fromList([80, 75, 3, 4]),
      );
      final docs = await repository().list();
      expect(docs, hasLength(2));
      final restored = docs.singleWhere((d) => d.format == DocumentFormat.pdf);
      expect(restored.name, 'Safety.PDF');
      expect(await File(restored.filePath!).readAsBytes(), bytes);
      await expectLater(
        repository().updateDocx(pdf.id, Uint8List.fromList([80, 75, 3, 4])),
        throwsStateError,
      );
      expect(await File(restored.filePath!).readAsBytes(), bytes);
      await expectLater(
        repository().storePdf('bad.pdf', Uint8List.fromList([80, 75, 3, 4])),
        throwsArgumentError,
      );
      await expectLater(
        repository().storePdf('bad.docx', bytes),
        throwsArgumentError,
      );
      expect(await repository().list(), hasLength(2));
    },
  );
}
