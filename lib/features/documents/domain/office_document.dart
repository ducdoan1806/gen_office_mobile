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
  String get sourceExtension =>
      legacyDoc ? 'doc' : name.toLowerCase().split('.').last;
  bool get needsConversion =>
      sourceExtension != format.name &&
      const ['doc', 'xls', 'ppt', 'csv'].contains(sourceExtension);
  String get editorName => needsConversion
      ? '${name.substring(0, name.lastIndexOf('.'))}.${format.name}'
      : name;
}

DocumentFormat? editableFormat(String name) {
  final extension = name.toLowerCase().split('.').last;
  return switch (extension) {
    'doc' || 'docx' => DocumentFormat.docx,
    'xls' || 'csv' || 'xlsx' => DocumentFormat.xlsx,
    'ppt' || 'pptx' => DocumentFormat.pptx,
    _ => null,
  };
}
