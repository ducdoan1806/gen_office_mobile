import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/data/csv_workbook_codec.dart';
import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/documents/data/android_document_files.dart';
import 'package:gen_office_mobile/features/documents/data/legacy_doc_converter.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';

class FakeOfficeConverter extends LegacyDocConverter {
  bool fail = false;
  final calls = <String>[];
  @override
  Future<Uint8List> convertOffice(
    Uint8List bytes,
    String source,
    String target,
  ) async {
    calls.add('$source:$target');
    if (fail) throw StateError('conversion failed');
    return Uint8List.fromList(
      target.endsWith('x')
          ? [80, 75, 3, 4, bytes.last]
          : [208, 207, 17, 224, 161, 177, 26, 225, bytes.last],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'CSV preserves UTF-8 BOM, separator, quoted multiline fields and leading zeros',
    () {
      final source = Uint8List.fromList([
        239,
        187,
        191,
        ...utf8.encode(
          'sep=;\r\nMã;Nội dung;Số lượng\r\n0012;"Dòng 1\nDòng 2; ""có dấu""";25\r\n',
        ),
      ]);
      final xlsx = CsvWorkbookCodec.toXlsx(source);
      expect(CsvWorkbookCodec.fromXlsx(xlsx, source), source);
      final xml = utf8.decode(
        ZipDecoder()
                .decodeBytes(xlsx)
                .findFile('xl/worksheets/sheet1.xml')!
                .content
            as List<int>,
      );
      expect(xml, contains('0012'));
      expect(xml, contains('<v>25</v>'));
    },
  );
  test('CSV preserves UTF-16 LE/BE and tab separators', () {
    const text = 'Mã\tTên\n001\tNhà máy';
    for (final little in [true, false]) {
      final source = Uint8List.fromList([
        ...(little ? [255, 254] : [254, 255]),
        for (final c in text.codeUnits)
          ...(little ? [c & 255, c >> 8] : [c >> 8, c & 255]),
      ]);
      expect(
        CsvWorkbookCodec.fromXlsx(CsvWorkbookCodec.toXlsx(source), source),
        source,
      );
    }
  });
  test('CSV rejects malformed quoting and unsupported encoding', () {
    expect(
      () => CsvWorkbookCodec.toXlsx(
        Uint8List.fromList(utf8.encode('a,"unclosed')),
      ),
      throwsFormatException,
    );
    expect(
      () => CsvWorkbookCodec.toXlsx(Uint8List.fromList([0x81, 0x82, 0xff])),
      throwsFormatException,
    );
  });
  test(
    'CSV accepts a calculated empty string but rejects missing formula cache',
    () {
      final source = Uint8List.fromList(utf8.encode('value\n'));
      Uint8List formula(String cached) {
        final zip = ZipDecoder().decodeBytes(CsvWorkbookCodec.toXlsx(source));
        const path = 'xl/worksheets/sheet1.xml';
        final file = zip.findFile(path)!;
        final xml = utf8
            .decode(file.content as List<int>)
            .replaceFirst(
              RegExp(r'<c\b[^>]*>[\s\S]*?</c>'),
              '<c r="A1" t="str"><f>""</f>$cached</c>',
            );
        final bytes = utf8.encode(xml);
        zip.addFile(ArchiveFile(path, bytes.length, bytes));
        return Uint8List.fromList(ZipEncoder().encode(zip)!);
      }

      expect(
        utf8.decode(CsvWorkbookCodec.fromXlsx(formula('<v/>'), source)),
        '\n',
      );
      expect(
        () => CsvWorkbookCodec.fromXlsx(formula(''), source),
        throwsStateError,
      );
    },
  );
  test(
    'CSV does not interpret formula-like input or discard a second worksheet',
    () async {
      final source = Uint8List.fromList(utf8.encode('=SUM(A2:A3),001\n'));
      final output = CsvWorkbookCodec.toXlsx(source);
      expect(CsvWorkbookCodec.fromXlsx(output, source), source);
      expect(
        () => CsvWorkbookCodec.fromXlsx(
          File('assets/samples/sheets-test.xlsx').readAsBytesSync(),
          source,
        ),
        throwsStateError,
      );
    },
  );
  for (final extension in ['xls', 'ppt', 'csv']) {
    test(
      '$extension original save keeps format, identity, cache and rollback',
      () async {
        final root = await Directory.systemTemp.createTemp('formats-qa-');
        addTearDown(() => root.delete(recursive: true));
        final converter = FakeOfficeConverter();
        final format = extension == 'ppt'
            ? DocumentFormat.pptx
            : DocumentFormat.xlsx;
        final source = Uint8List.fromList(
          extension == 'csv'
              ? utf8.encode('Mã,Số lượng\r\n001,12\r\n')
              : [208, 207, 17, 224, 161, 177, 26, 225, 1],
        );
        final writes = <Uint8List>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidDocumentFiles.channel, (
              call,
            ) async {
              if (call.method == 'write') {
                writes.add((call.arguments as Map)['bytes'] as Uint8List);
                return null;
              }
              throw StateError('Unexpected IO');
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(AndroidDocumentFiles.channel, null),
        );
        LocalDocumentRepository repo() => LocalDocumentRepository(
          documentsDirectory: () async => root,
          converter: converter,
        );
        final imported = await repo().storeOffice(
          'a.$extension',
          source,
          format: format,
          sourceUri: 'content://qa/$extension',
        );
        expect(imported.sourceExtension, extension);
        expect(imported.editorName, 'a.${format.name}');
        expect(writes, isEmpty);
        final cached = await File(imported.filePath!).readAsBytes();
        final saved = await repo().updateOffice(imported.id, cached);
        expect(saved.id, imported.id);
        expect(writes, hasLength(1));
        expect((await repo().list()).single.sourceExtension, extension);
        if (extension == 'csv') {
          expect(writes.single, source);
        } else {
          expect(converter.calls, [
            '$extension:${format.name}',
            '${format.name}:$extension',
          ]);
          expect(writes.single.take(8), [208, 207, 17, 224, 161, 177, 26, 225]);
          converter.fail = true;
          await expectLater(
            repo().updateOffice(imported.id, cached),
            throwsStateError,
          );
          expect(writes, hasLength(1));
          expect(await File(saved.filePath!).readAsBytes(), cached);
        }
      },
    );
  }
}
