import 'package:flutter/services.dart';

/// Conversion stays inside the Android app, in a separate native process.
class LegacyDocConverter {
  const LegacyDocConverter();
  static const channel = MethodChannel('genoffice/doc_conversion');
  Future<Uint8List> toDocx(Uint8List bytes) => _convert(bytes, 'docx');
  Future<Uint8List> toDoc(Uint8List bytes) => _convert(bytes, 'doc');
  Future<Uint8List> convertOffice(
    Uint8List bytes,
    String source,
    String target,
  ) async {
    if (source == 'doc' && target == 'docx') return toDocx(bytes);
    if (source == 'docx' && target == 'doc') return toDoc(bytes);
    final result = await channel.invokeMethod<Uint8List>('convert', {
      'bytes': bytes,
      'source': source,
      'target': target,
    });
    if (result == null || result.isEmpty) {
      throw StateError('Không chuyển đổi được tài liệu.');
    }
    return result;
  }

  Future<Uint8List> _convert(Uint8List bytes, String target) async {
    final result = await channel.invokeMethod<Uint8List>('convert', {
      'bytes': bytes,
      'target': target,
    });
    if (result == null || result.isEmpty) {
      throw StateError('Không chuyển đổi được tài liệu DOC.');
    }
    return result;
  }
}
