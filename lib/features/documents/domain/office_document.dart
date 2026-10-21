enum DocumentFormat { docx, xlsx, pptx, pdf, markdown }

class OfficeDocument {
  const OfficeDocument({
    required this.id,
    required this.name,
    required this.format,
    this.assetPath,
    this.filePath,
    this.createdAt,
    this.updatedAt,
    this.sizeBytes,
  });
  final String id;
  final String name;
  final DocumentFormat format;
  final String? assetPath;
  final String? filePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? sizeBytes;
}
