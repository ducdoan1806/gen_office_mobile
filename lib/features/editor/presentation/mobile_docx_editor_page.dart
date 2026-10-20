import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../documents/domain/office_document.dart';
import '../data/editor_asset_server.dart';
import '../data/webview_document_editor_bridge.dart';
import '../domain/editor_document.dart';

class MobileDocxEditorPage extends StatefulWidget {
  const MobileDocxEditorPage({
    super.key,
    required this.document,
    this.bridge,
    this.onSaved,
    this.onReady,
  });
  final OfficeDocument document;

  /// Injection point for device integration tests; normal UI owns its bridge.
  final WebViewDocumentEditorBridge? bridge;
  final ValueChanged<EditorSaveResult>? onSaved;
  final VoidCallback? onReady;
  @override
  State<MobileDocxEditorPage> createState() => _MobileDocxEditorPageState();
}

class _MobileDocxEditorPageState extends State<MobileDocxEditorPage> {
  WebViewDocumentEditorBridge? _bridge;
  StreamSubscription<EditorSaveResult>? _saved;
  bool _viewCreated = false, _busy = true, _allowPop = false;
  String? _error;
  String _status = 'Đang khởi động editor…';
  late String _name = widget.document.name;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  @override
  void initState() {
    super.initState();
    if (_supported) {
      unawaited(_initialize());
    } else {
      _busy = false;
      _error = 'Editor WebView hiện hỗ trợ Android, iOS và macOS.';
    }
  }

  Future<EditorSaveResult> _persist(String name, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final exports = Directory('${directory.path}/GenOffice/exports');
    await exports.create(recursive: true);
    final output = File(
      '${exports.path}/${DateTime.now().microsecondsSinceEpoch}-$name',
    );
    final temporary = File('${output.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(output.path);
    return EditorSaveResult(name: name, path: output.path);
  }

  Future<void> _initialize() async {
    final bridge =
        widget.bridge ??
        WebViewDocumentEditorBridge(
          server: EditorAssetServer(persistExport: _persist),
        );
    _bridge = bridge;
    bridge.onPickDocument = () => unawaited(_pick());
    _saved = bridge.server.saved.listen((result) {
      widget.onSaved?.call(result);
      if (mounted) setState(() => _status = 'Đã lưu: ${result.path}');
    });
    try {
      await bridge.initialize();
      if (!mounted) return;
      setState(() => _viewCreated = true);
      await bridge.ready.future.timeout(const Duration(seconds: 45));
      if (!mounted) return;
      final asset = widget.document.assetPath;
      if (asset != null) {
        final data = await rootBundle.load(asset);
        await bridge.open(
          EditorDocument(
            id: widget.document.id,
            name: widget.document.name,
            bytes: data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            ),
          ),
        );
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Sẵn sàng · tài liệu lưu trong ứng dụng';
          widget.onReady?.call();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Không khởi động được editor: $error';
        });
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_bridge == null || !_bridge!.ready.isCompleted) return true;
    if (!await _bridge!.hasUnsavedChanges()) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thay đổi chưa lưu'),
            content: const Text('Bỏ các thay đổi chưa lưu để tiếp tục?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bỏ thay đổi'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _status = 'Lỗi: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() => _perform(() async {
    const group = XTypeGroup(
      label: 'Word DOCX',
      extensions: ['docx'],
      mimeTypes: [
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ],
      uniformTypeIdentifiers: ['org.openxmlformats.wordprocessingml.document'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    if (await file.length() > EditorAssetServer.maxDocumentBytes) {
      throw StateError('DOCX vượt giới hạn 20 MB');
    }
    if (!await _confirmDiscard()) return;
    final bytes = await file.readAsBytes();
    await _bridge!.open(
      EditorDocument(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: file.name,
        bytes: bytes,
      ),
    );
    if (mounted) {
      setState(() {
        _name = file.name;
        _status = 'Đã mở ${file.name}';
      });
    }
  });
  Future<void> _leave() async {
    if (_busy) return;
    try {
      if (!await _confirmDiscard()) return;
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Không kiểm tra được thay đổi: $error');
      }
      return;
    }
    if (mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    unawaited(_saved?.cancel());
    unawaited(_bridge?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || _error != null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_leave());
    },
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            key: const Key('open-docx'),
            tooltip: 'Mở DOCX',
            onPressed: _busy || _error != null ? null : _pick,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            key: const Key('save-docx'),
            tooltip: 'Lưu DOCX',
            onPressed: _busy || _error != null
                ? null
                : () => _perform(() async {
                    await _bridge!.save();
                  }),
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!),
                      ),
                    )
                  : _viewCreated
                  ? WebViewWidget(controller: _bridge!.controller)
                  : const Center(child: CircularProgressIndicator()),
            ),
            if (_bridge != null && _viewCreated)
              ValueListenableBuilder<String?>(
                valueListenable: _bridge!.error,
                builder: (context, error, child) => error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(error),
                      ),
              ),
            if (_error == null)
              Row(
                children: [
                  IconButton(
                    key: const Key('undo-docx'),
                    tooltip: 'Hoàn tác',
                    onPressed: _busy
                        ? null
                        : () => _perform(() => _bridge!.undo()),
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    key: const Key('redo-docx'),
                    tooltip: 'Làm lại',
                    onPressed: _busy
                        ? null
                        : () => _perform(() => _bridge!.redo()),
                    icon: const Icon(Icons.redo),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
