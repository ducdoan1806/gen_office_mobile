enum DocumentFormat { docx, xlsx, pptx, pdf, markdown }

class OfficeDocument {
  const OfficeDocument({
    required this.id,
    required this.name,
    required this.format,
    this.assetPath,
    this.filePath,
    this.sourceUri,
    this.createdAt,
    this.updatedAt,
    this.sizeBytes,
    this.legacyDoc = false,
    this.sourceHash,
  });
  final String id;
  final String name;
  final DocumentFormat format;
  final String? assetPath;
  final String? filePath;
  final String? sourceUri;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? sizeBytes;
  final bool legacyDoc;
  final String? sourceHash;
  String get editorName =>
      legacyDoc ? '${name.substring(0, name.length - 4)}.docx' : name;
}
