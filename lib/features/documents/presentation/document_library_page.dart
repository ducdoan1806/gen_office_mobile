import 'package:flutter/material.dart';
import '../../../app/dependencies.dart';
import '../../editor/presentation/document_editor_page.dart';
import '../../editor/presentation/mobile_docx_editor_page.dart';
import '../domain/office_document.dart';

class DocumentLibraryPage extends StatefulWidget {
  const DocumentLibraryPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<DocumentLibraryPage> createState() => _DocumentLibraryPageState();
}

class _DocumentLibraryPageState extends State<DocumentLibraryPage> {
  late final Future<List<OfficeDocument>> _documents = widget
      .dependencies
      .documents
      .list();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('GenOffice Mobile')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tài liệu mẫu • AI nhà máy: chế độ mock'),
        ),
        Expanded(
          child: FutureBuilder<List<OfficeDocument>>(
            future: _documents,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Không tải được danh sách tài liệu.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final documents = snapshot.data!;
              if (documents.isEmpty) {
                return const Center(child: Text('Chưa có tài liệu.'));
              }
              return ListView.builder(
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(document.name),
                    subtitle: Text(document.format.name.toUpperCase()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => document.format == DocumentFormat.docx
                            ? MobileDocxEditorPage(document: document)
                            : DocumentEditorPage(
                                document: document,
                                ai: widget.dependencies.ai,
                              ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
