enum DocumentFormat { docx, xlsx, pptx, pdf, markdown }

class OfficeDocument {
  const OfficeDocument({
    required this.id,
    required this.name,
    required this.format,
    this.assetPath,
  });
  final String id;
  final String name;
  final DocumentFormat format;
  final String? assetPath;
}
