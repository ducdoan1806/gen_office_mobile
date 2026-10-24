import 'dart:async';
import '../../ai/presentation/document_ai_sheet.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../documents/data/android_document_files.dart';
import '../../documents/data/local_document_repository.dart';
import '../../documents/domain/office_document.dart';
import '../../editor/data/editor_asset_server.dart';
import '../../editor/domain/editor_document.dart';

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({
    super.key,
    required this.document,
    this.onControllerCreated,
  });
  final OfficeDocument document;
  final ValueChanged<WebViewController>? onControllerCreated;
  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final _chat = DocumentChat();
  WebViewController? _controller;
  EditorAssetServer? _server;
  String? _error;
  bool _rendered = false;
  Timer? _timeout;
  int _aiSequence = 0;
  final _aiPending = <String, Completer<Map<String, dynamic>>>{};

  @override
  void initState() {
    super.initState();
    _chat.readDocument = () async {
      if (!_rendered || _controller == null || _error != null) {
        throw StateError('Chờ PDF mở xong.');
      }
      final id = 'pdf-ai-${++_aiSequence}';
      final pending = Completer<Map<String, dynamic>>();
      _aiPending[id] = pending;
      final response = pending.future.timeout(const Duration(seconds: 60));
      unawaited(
        response.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
      try {
        await _controller!.runJavaScript(
          'void window.genOfficePdfAiContext(${jsonEncode(id)});',
        );
        return await response;
      } finally {
        _aiPending.remove(id);
      }
    };
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        throw StateError('PDF viewer hiện được triển khai cho Android.');
      }
      final document = widget.document;
      final Uint8List bytes;
      if (document.sourceUri != null) {
        bytes = await const AndroidDocumentFiles().read(document.sourceUri!);
      } else if (document.filePath != null) {
        final file = File(document.filePath!);
        if (await file.length() > LocalDocumentRepository.maxImportBytes) {
          throw StateError('PDF vượt giới hạn 20 MB.');
        }
        bytes = await file.readAsBytes();
      } else {
        final data = await rootBundle.load(document.assetPath!);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      if (!mounted) return;
      if (bytes.length < 5 ||
          bytes.length > LocalDocumentRepository.maxImportBytes ||
          String.fromCharCodes(bytes.take(5)) != '%PDF-') {
        throw StateError('PDF không hợp lệ hoặc vượt giới hạn 20 MB.');
      }
      final server = EditorAssetServer(
        pdf: true,
        persistExport: (_, _) async => throw StateError('PDF chỉ hỗ trợ xem.'),
      );
      _server = server;
      await server.start();
      if (!mounted) {
        await server.close();
        return;
      }
      server.provideDocument(
        EditorDocument(id: document.id, name: document.name, bytes: bytes),
      );
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.enableZoom(true);
      await controller.addJavaScriptChannel(
        'GenOfficePdf',
        onMessageReceived: (message) {
          if (!mounted) return;
          try {
            final event = jsonDecode(message.message) as Map<String, dynamic>;
            if (event['type'] == 'aiContext') {
              final pending = _aiPending.remove(event['id']);
              if (pending != null && !pending.isCompleted) {
                event['error'] != null
                    ? pending.completeError(
                        StateError(event['error'].toString()),
                      )
                    : pending.complete(
                        Map<String, dynamic>.from(event['value'] as Map),
                      );
              }
            } else if (event['type'] == 'rendered') {
              _timeout?.cancel();
              setState(() => _rendered = true);
            } else if (event['type'] == 'error') {
              _timeout?.cancel();
              setState(() => _error = event['value'] as String);
            }
          } catch (_) {
            /* Ignore messages outside the reader protocol. */
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => server.allowsNavigation(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (event) {
            if (mounted && event.isForMainFrame == true) {
              setState(() => _error = 'Không tải được trình đọc PDF.');
            }
          },
        ),
      );
      if (!mounted) return;
      _timeout = Timer(const Duration(seconds: 60), () {
        if (mounted && !_rendered) {
          setState(
            () => _error = 'PDF mất quá lâu để hiển thị. Hãy mở lại file.',
          );
        }
      });
      setState(() => _controller = controller);
      widget.onControllerCreated?.call(controller);
      await controller.loadRequest(server.editorUri);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không mở được PDF. File có thể bị hỏng, vượt 20 MB hoặc đã mất quyền truy cập. Hãy quay lại và chọn mở file lần nữa.',
        );
      }
    }
  }

  @override
  void dispose() {
    _chat.dispose();
    for (final pending in _aiPending.values) {
      pending.completeError(StateError('PDF đã đóng.'));
    }
    _aiPending.clear();
    _timeout?.cancel();
    final server = _server;
    if (server != null) unawaited(server.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.small(
      tooltip: 'Trợ lý AI',
      onPressed: () => showDocumentAi(context, _chat, widget.document.name),
      child: const Icon(Icons.auto_awesome_outlined),
    ),
    appBar: AppBar(
      title: Text(
        widget.document.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      child: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : Column(
              children: [
                if (!_rendered) const LinearProgressIndicator(),
                if (_controller != null)
                  Expanded(child: WebViewWidget(controller: _controller!)),
              ],
            ),
    ),
  );
}
