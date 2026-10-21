import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../documents/domain/office_document.dart';
import '../../documents/domain/document_repository.dart';
import '../../documents/data/local_document_repository.dart';
import '../../documents/data/docx_file_picker.dart';
import '../../documents/data/android_document_files.dart';
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
    this.documents,
    this.onBridgeCreated,
    this.pickDocument = pickDocxFile,
  });
  final OfficeDocument document;
  final DocumentRepository? documents;
  final ValueChanged<WebViewDocumentEditorBridge>? onBridgeCreated;
  final Future<XFile?> Function() pickDocument;

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
  bool _saving = false;
  bool get _working => _busy || _saving;
  String? _error;
  String _status = 'Đang khởi động editor…';
  late String _name = widget.document.name;
  late OfficeDocument _currentDocument = widget.document;
  late final DocumentRepository _documents =
      widget.documents ?? LocalDocumentRepository();
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

  Future<EditorSaveResult> _saveLocked(
    Future<EditorSaveResult> Function() action,
  ) async {
    if (_saving) throw StateError('Đang lưu tài liệu. Vui lòng chờ.');
    if (mounted) setState(() => _saving = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<EditorSaveResult> _persist(String name, Uint8List bytes) =>
      _saveLocked(() => _persistCurrent(name, bytes));

  Future<EditorSaveResult> _persistCopy(String name, Uint8List bytes) =>
      _saveLocked(() => _persistNewCopy(name, bytes));

  Future<EditorSaveResult> _persistCurrent(String name, Uint8List bytes) async {
    String? sourceUri = _currentDocument.sourceUri;
    if (Platform.isAndroid && sourceUri == null) {
      if (mounted) setState(() => _status = 'Chọn file gốc để lưu thay đổi');
      final target = await const AndroidDocumentFiles().pick();
      if (target == null) throw StateError('Chưa lưu: bạn chưa chọn file gốc.');
      sourceUri = target.sourceUri;
    }
    if (_currentDocument.filePath == null && sourceUri != null) {
      await const AndroidDocumentFiles().write(sourceUri, bytes);
    }
    final saved = _currentDocument.filePath == null
        ? await _documents.storeDocx(
            name,
            bytes,
            isExport: true,
            sourceUri: sourceUri,
          )
        : await _documents.updateDocx(
            _currentDocument.id,
            bytes,
            sourceUri: sourceUri,
          );
    _currentDocument = saved;
    return EditorSaveResult(name: saved.name, path: saved.filePath!);
  }

  Future<EditorSaveResult> _persistNewCopy(String name, Uint8List bytes) async {
    String? sourceUri;
    if (Platform.isAndroid) {
      final target = await const AndroidDocumentFiles().pick(createName: name);
      if (target == null) throw StateError('Đã hủy lưu bản sao.');
      await const AndroidDocumentFiles().write(target.sourceUri, bytes);
      sourceUri = target.sourceUri;
      name = target.name;
    }
    final saved = await _documents.storeDocx(
      name,
      bytes,
      isExport: true,
      sourceUri: sourceUri,
    );
    _currentDocument = saved;
    return EditorSaveResult(name: saved.name, path: saved.filePath!);
  }

  Future<void> _initialize() async {
    final bridge =
        widget.bridge ??
        WebViewDocumentEditorBridge(
          server: EditorAssetServer(
            persistExport: _persist,
            persistCopy: _persistCopy,
          ),
        );
    _bridge = bridge;
    widget.onBridgeCreated?.call(bridge);
    bridge.onPickDocument = () => unawaited(_pick());
    _saved = bridge.server.saved.listen((result) {
      widget.onSaved?.call(result);
      if (mounted) {
        setState(() {
          _name = result.name;
          _status = _currentDocument.sourceUri != null
              ? 'Đã lưu vào file gốc: $_name'
              : 'Đã lưu $_name';
        });
      }
    });
    try {
      await bridge.initialize();
      if (!mounted) return;
      setState(() => _viewCreated = true);
      await bridge.ready.future.timeout(const Duration(seconds: 45));
      if (!mounted) return;
      final asset = widget.document.assetPath;
      final path = widget.document.filePath;
      if (asset != null || path != null) {
        final data = path != null ? null : await rootBundle.load(asset!);
        final bytes = widget.document.sourceUri != null
            ? await const AndroidDocumentFiles().read(
                widget.document.sourceUri!,
              )
            : path != null
            ? await File(path).readAsBytes()
            : data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await bridge.open(
          EditorDocument(
            id: widget.document.id,
            name: widget.document.name,
            bytes: bytes,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _status = _currentDocument.sourceUri != null
              ? 'Lưu sẽ cập nhật file gốc'
              : Platform.isAndroid
              ? 'Bản cũ trong app · Lưu để chọn file gốc'
              : 'Sẵn sàng · tài liệu lưu trong ứng dụng';
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
    if (_working) return;
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
    final file = await widget.pickDocument();
    if (file == null) return;
    if (await file.length() > EditorAssetServer.maxDocumentBytes) {
      throw StateError('DOCX vượt giới hạn 20 MB');
    }
    if (!await _confirmDiscard()) return;
    final bytes = await file.readAsBytes();
    final document = await _documents.storeDocx(
      file.name,
      bytes,
      sourceUri: file is SourceDocxFile ? file.sourceUri : null,
    );
    await _bridge!.open(
      EditorDocument(id: document.id, name: document.name, bytes: bytes),
    );
    _currentDocument = document;
    if (mounted) {
      setState(() {
        _name = file.name;
        _status = 'Đã mở ${file.name}';
      });
    }
  });
  Future<void> _leave() async {
    if (_working) return;
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
            onPressed: _working || _error != null ? null : _pick,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            key: const Key('save-docx'),
            tooltip: 'Lưu DOCX',
            onPressed: _working || _error != null
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
            if (_working) const LinearProgressIndicator(),
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
                    onPressed: _working
                        ? null
                        : () => _perform(() => _bridge!.undo()),
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    key: const Key('redo-docx'),
                    tooltip: 'Làm lại',
                    onPressed: _working
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
