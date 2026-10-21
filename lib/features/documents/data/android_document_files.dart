import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// A system-selected document, with a durable reference to its original file.
class SourceDocxFile extends XFile {
  SourceDocxFile(super.bytes, this.name, this.sourceUri) : super.fromData();
  @override
  final String name;
  final String sourceUri;
}

class AndroidDocumentFiles {
  const AndroidDocumentFiles();
  static const channel = MethodChannel('genoffice/document_files');

  Future<SourceDocxFile?> pick({String? createName, String? initialUri}) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      createName == null ? 'open' : 'create',
      {
        if (createName != null) 'name': createName,
        if (initialUri != null) 'initialUri': initialUri,
      },
    );
    if (result == null) return null;
    return SourceDocxFile(
      result['bytes'] as Uint8List,
      result['name'] as String,
      result['uri'] as String,
    );
  }

  Future<Uint8List> read(String uri) async =>
      (await channel.invokeMethod<Uint8List>('read', {'uri': uri}))!;

  Future<void> write(String uri, Uint8List bytes) =>
      channel.invokeMethod<void>('write', {'uri': uri, 'bytes': bytes});
}
