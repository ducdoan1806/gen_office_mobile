import 'dart:typed_data';

class EditorDocument {
  const EditorDocument({
    required this.id,
    required this.name,
    required this.bytes,
  });
  final String id;
  final String name;
  final Uint8List bytes;
}

class EditorSaveResult {
  const EditorSaveResult({required this.name, required this.path});
  final String name;
  final String path;
}
