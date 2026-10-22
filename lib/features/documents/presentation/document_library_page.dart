import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../../app/dependencies.dart';
import '../../editor/presentation/document_editor_page.dart';
import '../../editor/presentation/mobile_docx_editor_page.dart';
import '../domain/office_document.dart';
import '../data/document_file_picker.dart';
import '../../pdf/presentation/pdf_viewer_page.dart';
import '../data/android_document_files.dart';
import '../../editor/data/document_recovery_store.dart';
import '../../editor/presentation/recovery_documents.dart';
import '../../editor/data/webview_document_editor_bridge.dart';
import '../data/local_document_repository.dart';

class DocumentLibraryPage extends StatefulWidget {
  const DocumentLibraryPage({
    super.key,
    required this.dependencies,
    this.pickDocument = pickOfficeFile,
    this.recoveryStore,
    this.onBridgeCreated,
  });
  final AppDependencies dependencies;
  final DocumentRecoveryStore? recoveryStore;
  final ValueChanged<WebViewDocumentEditorBridge>? onBridgeCreated;
  final Future<XFile?> Function() pickDocument;
  @override
  State<DocumentLibraryPage> createState() => _DocumentLibraryPageState();
}

class _DocumentLibraryPageState extends State<DocumentLibraryPage> {
  bool _importing = false;
  int _reloadRevision = 0;
  late final _recovery = widget.recoveryStore ?? DocumentRecoveryStore();
  late Future<List<OfficeDocument>> _documents = widget.dependencies.documents
      .list();

  void _reload() {
    final documents = widget.dependencies.documents.list();
    setState(() {
      _documents = documents;
      _reloadRevision++;
    });
  }

  Future<void> _open(
    OfficeDocument document, {
    RecoverySnapshot? recovery,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => document.format == DocumentFormat.pdf
            ? PdfViewerPage(document: document)
            : document.format == DocumentFormat.docx
            ? MobileDocxEditorPage(
                document: document,
                recoveryStore: _recovery,
                initialRecovery: recovery,
                onBridgeCreated: widget.onBridgeCreated,
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
      final file = await widget.pickDocument();
      if (file == null) return;
      final name = file.name.toLowerCase();
      final pdf = name.endsWith('.pdf');
      final legacyDoc = name.endsWith('.doc');
      if (!pdf && !legacyDoc && !name.endsWith('.docx')) {
        throw StateError('Định dạng file chưa được hỗ trợ.');
      }
      if (await file.length() > LocalDocumentRepository.maxImportBytes) {
        throw StateError('Tài liệu vượt giới hạn 20 MB.');
      }
      final bytes = await file.readAsBytes();
      final uri = file is SourceDocxFile ? file.sourceUri : null;
      final document = pdf
          ? await widget.dependencies.documents.storePdf(
              file.name,
              bytes,
              sourceUri: uri,
            )
          : await widget.dependencies.documents.storeDocx(
              file.name,
              bytes,
              sourceUri: uri,
              legacyDoc: legacyDoc,
            );
      if (!mounted) return;
      _reload();
      await _open(document);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không mở được tài liệu: $error')),
        );
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
      key: const Key('open-document'),
      onPressed: _importing ? null : () => _import(),
      icon: _importing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            )
          : const Icon(Icons.add),
      label: const Text('Mở tài liệu'),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecoveryDocuments(
          key: ValueKey(_reloadRevision),
          store: _recovery,
          onRestore: (snapshot) async {
            final documents = await widget.dependencies.documents.list();
            final current = documents.where(
              (d) => d.id == snapshot.document.id,
            );
            await _open(
              current.isEmpty ? snapshot.document : current.first,
              recovery: snapshot,
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tài liệu gần đây'),
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
                  child: Text('Chưa có tài liệu. Nhấn “Mở tài liệu” để thêm.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  return ListTile(
                    leading: Icon(
                      document.format == DocumentFormat.pdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(document.name),
                    subtitle: Text(
                      [
                        document.legacyDoc
                            ? 'DOC'
                            : document.format.name.toUpperCase(),
                        document.sourceUri != null
                            ? 'File gốc'
                            : 'Bản trong app',
                        if (document.sizeBytes != null)
                          '${(document.sizeBytes! / 1024).ceil()} KB',
                        if (document.updatedAt != null ||
                            document.createdAt != null)
                          _date(document.updatedAt ?? document.createdAt!),
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
