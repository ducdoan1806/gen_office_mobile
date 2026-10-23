import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// CSV is values-only. Keep its dialect/encoding separately from the XLSX cache.
class CsvWorkbookCodec {
  static const maxCells = 500000;
  static String _decode(Uint8List bytes) {
    if (bytes.length >= 2 &&
        ((bytes[0] == 255 && bytes[1] == 254) ||
            (bytes[0] == 254 && bytes[1] == 255))) {
      if (bytes.length.isOdd) {
        throw const FormatException('CSV UTF-16 bị hỏng.');
      }
      final little = bytes[0] == 255;
      return String.fromCharCodes([
        for (var i = 2; i < bytes.length; i += 2)
          little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
      ]);
    }
    try {
      return utf8.decode(bytes).replaceFirst(RegExp('^\uFEFF'), '');
    } on FormatException {
      throw const FormatException('CSV cần mã hóa UTF-8 hoặc UTF-16 có BOM.');
    }
  }

  static List<List<String>> parse(String text, String separator) {
    final rows = <List<String>>[], row = <String>[];
    var value = StringBuffer();
    var quoted = false, closed = false, cells = 0;
    void field() {
      row.add(value.toString());
      value = StringBuffer();
      closed = false;
      if (++cells > maxCells) {
        throw const FormatException('CSV vượt giới hạn 500.000 ô.');
      }
    }

    void endRow() {
      field();
      rows.add(List.of(row));
      row.clear();
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            value.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          value.write(c);
        }
        continue;
      }
      if (c == separator) {
        field();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else if (c == '"' && value.isEmpty && !closed) {
        quoted = true;
      } else {
        if (closed) {
          throw const FormatException('Dấu ngoặc kép CSV không hợp lệ.');
        }
        value.write(c);
      }
    }
    if (quoted) throw const FormatException('CSV thiếu dấu đóng ngoặc kép.');
    if (value.isNotEmpty || row.isNotEmpty || closed) endRow();
    if (rows.any((r) => r.length > 16384) || rows.length > 1048576) {
      throw const FormatException('CSV vượt kích thước bảng tính.');
    }
    return rows;
  }

  static ({String separator, String body, String declaration, String newline})
  _dialect(String text) {
    final header = RegExp(
      r'^sep=([,;\t])\r?\n',
      caseSensitive: false,
    ).firstMatch(text);
    final body = header == null ? text : text.substring(header.end);
    var separator = header?.group(1) ?? ',';
    if (header == null) {
      var best = 0;
      for (final candidate in [',', ';', '\t']) {
        try {
          final rows = parse(body, candidate).take(40).toList();
          final widths = <int, int>{};
          for (final row in rows) {
            if (row.length > 1) {
              widths.update(row.length, (n) => n + 1, ifAbsent: () => 1);
            }
          }
          final score = widths.entries.fold<int>(
            0,
            (a, e) => a > e.value * 100 + e.key ? a : e.value * 100 + e.key,
          );
          if (score > best) {
            best = score;
            separator = candidate;
          }
        } on FormatException {
          /* Another delimiter can explain the quote boundary. */
        }
      }
    }
    return (
      separator: separator,
      body: body,
      declaration: header?.group(0) ?? '',
      newline: text.contains('\r\n') ? '\r\n' : '\n',
    );
  }

  static String _column(int n) {
    var result = '';
    for (n++; n > 0; n = (n - 1) ~/ 26) {
      result = String.fromCharCode(65 + (n - 1) % 26) + result;
    }
    return result;
  }

  static Uint8List toXlsx(Uint8List source) {
    final dialect = _dialect(_decode(source)),
        rows = parse(dialect.body, dialect.separator);
    String xml(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);
    final sheet = StringBuffer(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    );
    for (var r = 0; r < rows.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        if (v.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'))) {
          throw const FormatException(
            'CSV chứa ký tự điều khiển không hợp lệ.',
          );
        }
        // Only unambiguous, safely representable numbers become numeric cells.
        final number =
            RegExp(r'^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$').hasMatch(v) &&
            v.replaceAll(RegExp(r'[^0-9]'), '').length <= 15;
        if (number) {
          sheet.write('<c r="${_column(c)}${r + 1}"><v>$v</v></c>');
        } else {
          sheet.write(
            '<c r="${_column(c)}${r + 1}" t="inlineStr"><is><t xml:space="preserve">${xml(v)}</t></is></c>',
          );
        }
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');
    final parts = {
      '[Content_Types].xml':
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels':
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml':
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="CSV" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/worksheets/sheet1.xml': sheet.toString(),
    };
    final zip = Archive();
    for (final e in parts.entries) {
      final bytes = utf8.encode(e.value);
      zip.addFile(ArchiveFile(e.key, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(zip)!);
  }

  static Uint8List fromXlsx(Uint8List bytes, Uint8List template) {
    final original = _decode(template), dialect = _dialect(original);
    final zip = ZipDecoder().decodeBytes(bytes);
    var total = 0;
    for (final file in zip.files) {
      total += file.size;
      if (file.size > 64 * 1024 * 1024 || total > 256 * 1024 * 1024) {
        throw const FormatException('XLSX vượt giới hạn giải nén.');
      }
    }
    XmlDocument xml(String path) {
      final file = zip.findFile(path);
      if (file == null) throw const FormatException('Thiếu nội dung XLSX.');
      final text = utf8.decode(file.content as List<int>);
      if (RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(text)) {
        throw const FormatException('XML không hợp lệ.');
      }
      return XmlDocument.parse(text);
    }

    Iterable<XmlElement> elements(XmlNode node, String name) => node.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == name);
    final sheets = elements(xml('xl/workbook.xml'), 'sheet').toList();
    if (sheets.length != 1) {
      throw StateError(
        'CSV chỉ lưu một sheet. Hãy dùng Lưu thành bản mới để xuất XLSX.',
      );
    }
    final id = sheets.single.attributes
        .firstWhere((a) => a.name.local == 'id')
        .value;
    final rel = elements(
      xml('xl/_rels/workbook.xml.rels'),
      'Relationship',
    ).firstWhere((r) => r.getAttribute('Id') == id);
    final target = rel.getAttribute('Target')!;
    final path = target.startsWith('/')
        ? target.substring(1)
        : Uri.parse('xl/workbook.xml').resolve(target).path;
    final shared = zip.findFile('xl/sharedStrings.xml') == null
        ? <String>[]
        : elements(xml('xl/sharedStrings.xml'), 'si')
              .map((s) => elements(s, 't').map((t) => t.innerText).join())
              .toList();
    final rows = <int, Map<int, String>>{};
    var count = 0;
    for (final cell in elements(xml(path), 'c')) {
      final ref = RegExp(
        r'^([A-Z]+)([1-9][0-9]*)$',
      ).firstMatch(cell.getAttribute('r') ?? '');
      if (ref == null) continue;
      var col = 0;
      for (final c in ref.group(1)!.codeUnits) {
        col = col * 26 + c - 64;
      }
      final row = int.parse(ref.group(2)!) - 1;
      col--;
      if (row >= 1048576 || col >= 16384 || ++count > maxCells) {
        throw const FormatException('CSV vượt giới hạn kích thước.');
      }
      final type = cell.getAttribute('t');
      final cachedValue = elements(cell, 'v').firstOrNull;
      final value = cachedValue?.innerText ?? '';
      final text = type == 'inlineStr'
          ? elements(cell, 't').map((t) => t.innerText).join()
          : type == 's'
          ? shared[int.parse(value)]
          : type == 'b'
          ? (value == '1' ? 'TRUE' : 'FALSE')
          : value;
      if (elements(cell, 'f').isNotEmpty && cachedValue == null) {
        throw StateError('Công thức chưa tính xong. Hãy đợi rồi lưu lại.');
      }
      (rows[row] ??= <int, String>{})[col] = text;
    }
    final maxRow = rows.keys.fold<int>(-1, (a, b) => a > b ? a : b),
        maxCol = rows.values
            .expand((r) => r.keys)
            .fold<int>(-1, (a, b) => a > b ? a : b);
    if ((maxRow + 1) * (maxCol + 1) > maxCells) {
      throw const FormatException('CSV vượt giới hạn 500.000 ô.');
    }
    String field(String s) =>
        s.contains(dialect.separator) || s.contains(RegExp('["\r\n]'))
        ? '"${s.replaceAll('"', '""')}"'
        : s;
    final out = StringBuffer(dialect.declaration);
    for (var r = 0; r <= maxRow; r++) {
      out.write(
        [
          for (var c = 0; c <= maxCol; c++) field(rows[r]?[c] ?? ''),
        ].join(dialect.separator),
      );
      if (r < maxRow || original.endsWith('\n') || original.endsWith('\r')) {
        out.write(dialect.newline);
      }
    }
    final text = out.toString();
    if (template.length >= 2 &&
        ((template[0] == 255 && template[1] == 254) ||
            (template[0] == 254 && template[1] == 255))) {
      final little = template[0] == 255;
      return Uint8List.fromList([
        template[0],
        template[1],
        for (final c in text.codeUnits)
          ...(little ? [c & 255, c >> 8] : [c >> 8, c & 255]),
      ]);
    }
    return Uint8List.fromList([
      if (template.length >= 3 &&
          template[0] == 239 &&
          template[1] == 187 &&
          template[2] == 191) ...[
        239,
        187,
        191,
      ],
      ...utf8.encode(text),
    ]);
  }
}
