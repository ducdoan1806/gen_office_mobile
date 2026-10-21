import 'package:flutter/material.dart';
import '../../../app/dependencies.dart';
import '../../editor/presentation/document_editor_page.dart';
import '../../editor/presentation/mobile_docx_editor_page.dart';
import '../domain/office_document.dart';
import '../data/docx_file_picker.dart';
import '../data/local_document_repository.dart';

class DocumentLibraryPage extends StatefulWidget {
  const DocumentLibraryPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<DocumentLibraryPage> createState() => _DocumentLibraryPageState();
}

class _DocumentLibraryPageState extends State<DocumentLibraryPage> {
  bool _importing = false;
  late Future<List<OfficeDocument>> _documents = widget.dependencies.documents
      .list();

  void _reload() {
    setState(() => _documents = widget.dependencies.documents.list());
  }

  Future<void> _open(OfficeDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => document.format == DocumentFormat.docx
            ? MobileDocxEditorPage(
                document: document,
                documents: widget.dependencies.documents,
              )
            : DocumentEditorPage(
                document: document,
                ai: widget.dependencies.ai,
              ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final file = await pickDocxFile();
      if (file == null) return;
      if (await file.length() > LocalDocumentRepository.maxImportBytes) {
        throw StateError('DOCX vượt giới hạn 20 MB.');
      }
      final document = await widget.dependencies.documents.storeDocx(
        file.name,
        await file.readAsBytes(),
      );
      if (!mounted) return;
      _reload();
      await _open(document);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không nhập được DOCX: $error')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('GenOffice Mobile'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('import-docx'),
      onPressed: _importing ? null : _import,
      icon: _importing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            )
          : const Icon(Icons.add),
      label: const Text('Nhập DOCX'),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tài liệu của bạn'),
        ),
        Expanded(
          child: FutureBuilder<List<OfficeDocument>>(
            future: _documents,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Không tải được danh sách tài liệu.'),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final documents = snapshot.data!;
              if (documents.isEmpty) {
                return const Center(
                  child: Text('Chưa có tài liệu. Nhấn “Nhập DOCX” để thêm.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(document.name),
                    subtitle: Text(
                      [
                        document.format.name.toUpperCase(),
                        if (document.sizeBytes != null)
                          '${(document.sizeBytes! / 1024).ceil()} KB',
                        if (document.createdAt != null)
                          _date(document.createdAt!),
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(document),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
