import 'dart:async';
import 'package:flutter/material.dart';
import '../../ai/domain/factory_ai_service.dart';
import '../../documents/domain/office_document.dart';

class DocumentEditorPage extends StatefulWidget {
  const DocumentEditorPage({
    super.key,
    required this.document,
    required this.ai,
  });
  final OfficeDocument document;
  final FactoryAiService ai;
  @override
  State<DocumentEditorPage> createState() => _DocumentEditorPageState();
}

class _DocumentEditorPageState extends State<DocumentEditorPage> {
  final _instruction = TextEditingController();
  StreamSubscription<AiEvent>? _subscription;
  String? _requestId;
  String _response = 'Nhập yêu cầu để thử AI mock.';

  void _run() {
    final instruction = _instruction.text.trim();
    if (instruction.isEmpty || _requestId != null) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _requestId = id;
      _response = '';
    });
    _subscription = widget.ai
        .run(
          requestId: id,
          instruction: instruction,
          context: DocumentContext(
            documentId: widget.document.id,
            revision: 0,
            excerpts: const [],
          ),
        )
        .listen(
          (event) {
            if (!mounted || _requestId != id) return;
            setState(() {
              if (event.type == AiEventType.text) {
                _response = event.text;
              } else if (event.type == AiEventType.status) {
                _response = event.text;
              }
            });
          },
          onError: (Object error) {
            if (!mounted || _requestId != id) return;
            setState(() {
              _response = 'Không thể gọi AI: $error';
              _requestId = null;
            });
          },
          onDone: () {
            if (!mounted || _requestId != id) return;
            setState(() => _requestId = null);
          },
        );
  }

  Future<void> _stop() async {
    final id = _requestId;
    if (id == null) return;
    setState(() {
      _requestId = null;
      _response = 'Đã dừng yêu cầu.';
    });
    await _subscription?.cancel();
    try {
      await widget.ai.cancel(id);
    } catch (_) {
      /* UI cancellation still completes. */
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    final id = _requestId;
    if (id != null) unawaited(widget.ai.cancel(id).catchError((Object _) {}));
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.document.name)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.article_outlined, size: 48),
                  SizedBox(height: 12),
                  Text('Vùng editor Office'),
                  SizedBox(height: 8),
                  Text(
                    'Chưa tích hợp engine GenOffice. Đây là màn hình khung, chưa đọc hoặc chỉnh sửa file thực tế.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Trợ lý AI nhà máy',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instruction,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ví dụ: Tóm tắt quy trình vận hành',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _requestId == null ? _run : null,
                child: const Text('Gửi yêu cầu'),
              ),
              const SizedBox(width: 12),
              if (_requestId != null)
                TextButton(onPressed: _stop, child: const Text('Dừng')),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(_response),
        ],
      ),
    ),
  );
}
