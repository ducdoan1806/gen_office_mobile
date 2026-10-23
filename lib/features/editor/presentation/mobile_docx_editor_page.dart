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
import '../../documents/data/document_file_picker.dart';
import '../../pdf/presentation/pdf_viewer_page.dart';
import '../../documents/data/android_document_files.dart';
import '../../documents/data/legacy_doc_converter.dart';
import '../../documents/data/csv_workbook_codec.dart';
import 'dart:isolate';
import '../data/editor_asset_server.dart';
import '../data/document_recovery_store.dart';
import '../data/webview_document_editor_bridge.dart';
import '../domain/editor_document.dart';

class MobileDocxEditorPage extends StatefulWidget {
  const MobileDocxEditorPage({
    super.key,
    required this.document,
    this.bridge,
    this.recoveryStore,
    this.initialRecovery,
    this.checkpointInterval = const Duration(seconds: 5),
    this.onSaved,
    this.onReady,
    this.documents,
    this.onBridgeCreated,
    this.pickDocument = pickOfficeFile,
  });
  final OfficeDocument document;
  final DocumentRecoveryStore? recoveryStore;
  final RecoverySnapshot? initialRecovery;
  final Duration checkpointInterval;
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

class _MobileDocxEditorPageState extends State<MobileDocxEditorPage>
    with WidgetsBindingObserver {
  WebViewDocumentEditorBridge? _bridge;
  StreamSubscription<EditorSaveResult>? _saved;
  bool _viewCreated = false, _busy = true, _allowPop = false;
  bool _saving = false, _checkpointing = false;
  Timer? _checkpointTimer;
  Future<bool>? _checkpointFuture;
  OfficeDocument? _recoveryTarget;
  String? _baseHash;
  bool _sourceConflict = false;
  String? _confirmedCsvId;
  late final _recovery = widget.recoveryStore ?? DocumentRecoveryStore();
  bool get _working => _busy || _saving || _checkpointing;
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
    WidgetsBinding.instance.addObserver(this);
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
      await _checkpointFuture;
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
    final previousId = _currentDocument.id;
    if (_currentDocument.sourceExtension == 'csv' &&
        _confirmedCsvId != previousId) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lưu dữ liệu CSV'),
          content: const Text(
            'CSV chỉ lưu giá trị trong một sheet, không giữ định dạng và công thức. Chọn Lưu thành bản mới nếu muốn giữ đầy đủ trong XLSX.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu CSV'),
            ),
          ],
        ),
      );
      if (accepted != true) {
        throw StateError('Đã hủy lưu CSV. Bản tạm vẫn được giữ.');
      }
      _confirmedCsvId = previousId;
    }
    if (_sourceConflict && !await _confirmSourceOverwrite()) {
      throw StateError('Chưa lưu. Bản tạm khôi phục vẫn được giữ lại.');
    }
    if (_currentDocument.filePath == null) return _persistNewCopy(name, bytes);
    String? sourceUri = _currentDocument.sourceUri;
    if (Platform.isAndroid && sourceUri == null) {
      if (mounted) setState(() => _status = 'Chọn file gốc để lưu thay đổi');
      final target = await const AndroidDocumentFiles().pick(
        allDocuments: _currentDocument.needsConversion,
        format: _currentDocument.sourceExtension,
      );
      if (target == null) throw StateError('Chưa lưu: bạn chưa chọn file gốc.');
      if (!target.name.toLowerCase().endsWith(
        '.${_currentDocument.sourceExtension}',
      )) {
        throw StateError(
          'Hãy chọn đúng định dạng file gốc, hoặc dùng Lưu thành bản mới.',
        );
      }
      sourceUri = target.sourceUri;
    }
    final saved = await _documents.updateOffice(
      previousId,
      bytes,
      sourceUri: sourceUri,
    );
    await _clearRecoveryAfterSave(previousId);
    _baseHash = saved.sourceHash ?? DocumentRecoveryStore.hash(bytes);
    _sourceConflict = false;
    _currentDocument = saved;
    return EditorSaveResult(name: saved.editorName, path: saved.filePath!);
  }

  Future<EditorSaveResult> _persistNewCopy(String name, Uint8List bytes) async {
    final previousId = _currentDocument.id;
    String? sourceUri;
    if (Platform.isAndroid) {
      final target = await const AndroidDocumentFiles().pick(createName: name);
      if (target == null) throw StateError('Đã hủy lưu bản sao.');
      await const AndroidDocumentFiles().write(target.sourceUri, bytes);
      sourceUri = target.sourceUri;
      name = target.name;
    }
    final saved = await _documents.storeOffice(
      name,
      bytes,
      isExport: true,
      format: _currentDocument.format,
      sourceUri: sourceUri,
    );
    await _clearRecoveryAfterSave(previousId);
    _baseHash = DocumentRecoveryStore.hash(bytes);
    _sourceConflict = false;
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
            persistRecovery: _persistRecovery,
            format: _currentDocument.format.name,
          ),
        );
    _bridge = bridge;
    widget.onBridgeCreated?.call(bridge);
    bridge.onPickDocument = () => unawaited(_pick());
    _saved = bridge.server.saved.listen((result) {
      widget.onSaved?.call(result);
      if (mounted) {
        setState(() {
          _name = _currentDocument.name;
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
      if (!await _loadDocument(
        widget.document,
        recovery: widget.initialRecovery,
      )) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'Đã hủy mở tài liệu.';
          });
        }
        return;
      }
      _checkpointTimer = Timer.periodic(
        widget.checkpointInterval,
        (_) => unawaited(_checkpoint()),
      );
      if (mounted) {
        setState(() => _busy = false);
        widget.onReady?.call();
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

  Future<Uint8List> _readSource(OfficeDocument document) async {
    if (document.sourceUri != null) {
      return const AndroidDocumentFiles().read(document.sourceUri!);
    }
    if (document.filePath != null) {
      return File(document.filePath!).readAsBytes();
    }
    final data = await rootBundle.load(document.assetPath!);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<bool> _loadDocument(
    OfficeDocument document, {
    RecoverySnapshot? recovery,
    Uint8List? sourceBytes,
    bool ignoreRecovery = false,
  }) async {
    var pending = recovery;
    if (pending == null && !ignoreRecovery) {
      try {
        pending = await _recovery.find(document.id);
      } catch (_) {
        if (!mounted) return false;
        final openSource = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Không đọc được bản tạm'),
            content: const Text(
              'Bản tạm không đọc được. Bạn có thể bỏ bản tạm này để mở file gốc, hoặc chọn Để sau để giữ dữ liệu lại kiểm tra. File gốc vẫn được giữ nguyên.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bỏ bản tạm, mở gốc'),
              ),
            ],
          ),
        );
        if (openSource != true) return false;
        await _recovery.clear(document.id);
      }
    }
    if (!mounted) return false;
    if (pending != null && recovery == null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Có bản tạm chưa lưu'),
          content: Text(
            '${document.name} có thay đổi chưa lưu. Bạn muốn khôi phục để tiếp tục sửa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Bỏ bản tạm, mở gốc'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'restore'),
              child: const Text('Khôi phục'),
            ),
          ],
        ),
      );
      if (choice == null) return false;
      if (choice == 'discard') {
        await _recovery.clear(document.id);
        pending = null;
      }
    }
    Uint8List? original;
    try {
      original = sourceBytes ?? await _readSource(document);
    } catch (_) {
      if (pending == null) rethrow;
    }
    final bytes = pending != null
        ? await pending.read()
        : document.needsConversion && document.sourceUri != null
        ? document.sourceExtension == 'csv'
              ? await Isolate.run(() => CsvWorkbookCodec.toXlsx(original!))
              : await const LegacyDocConverter().convertOffice(
                  original!,
                  document.sourceExtension,
                  document.format.name,
                )
        : original!;
    final sourceHash = original == null
        ? null
        : document.needsConversion && document.sourceUri == null
        ? document.sourceHash ?? DocumentRecoveryStore.hash(original)
        : DocumentRecoveryStore.hash(original);
    await _bridge!.open(
      EditorDocument(id: document.id, name: document.editorName, bytes: bytes),
      recovered: pending != null,
    );
    _currentDocument = document;
    _name = document.name;
    _baseHash = pending != null ? pending.baseHash : sourceHash;
    _sourceConflict =
        pending != null &&
        (sourceHash == null || pending.baseHash != sourceHash);
    _status = pending != null
        ? 'Đã khôi phục bản tạm · bấm Lưu để cập nhật file gốc'
        : document.sourceUri != null
        ? 'Lưu sẽ cập nhật file gốc'
        : Platform.isAndroid
        ? 'Bản trong app · Lưu để chọn file gốc'
        : 'Sẵn sàng · tài liệu lưu trong ứng dụng';
    return true;
  }

  Future<bool> _confirmSourceOverwrite() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('File gốc đã thay đổi'),
            content: const Text(
              'File gốc khác với lúc tạo bản tạm, hoặc chưa đọc được nguồn. Lưu sẽ ghi đè bằng nội dung đang khôi phục. Bạn có thể dùng Lưu thành bản mới để giữ cả hai.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ghi đè file gốc'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _clearRecoveryAfterSave(String id) async {
    try {
      await _recovery.clear(id);
    } catch (_) {
      /* The source is already saved; retain the draft if cleanup fails. */
    }
  }

  Future<void> _persistRecovery(String id, Uint8List bytes) async {
    final target = _recoveryTarget;
    if (target == null || target.id != id || target.id != _currentDocument.id) {
      throw StateError(
        'Tài liệu đã thay đổi. Không ghi bản tạm vào tài liệu khác.',
      );
    }
    await _recovery.write(target, bytes, baseHash: _baseHash);
  }

  Future<bool> _checkpoint() {
    if (!mounted ||
        _working ||
        _error != null ||
        _bridge == null ||
        !_bridge!.ready.isCompleted) {
      return Future.value(false);
    }
    return _checkpointFuture = _runCheckpoint();
  }

  Future<bool> _runCheckpoint() async {
    setState(() => _checkpointing = true);
    _recoveryTarget = _currentDocument;
    try {
      final captured = await _bridge!.checkpoint(_currentDocument.id);
      if (captured && mounted) {
        setState(
          () => _status = 'Đã lưu bản tạm · file gốc chưa được cập nhật',
        );
      }
      return captured;
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Chưa lưu được bản tạm. Hãy bấm Lưu để giữ thay đổi.',
        );
      }
      return false;
    } finally {
      _recoveryTarget = null;
      _checkpointFuture = null;
      if (mounted) setState(() => _checkpointing = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_checkpoint());
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
      throw StateError('Tài liệu vượt giới hạn 20 MB');
    }
    if (!await _confirmDiscard()) return;
    final bytes = await file.readAsBytes();
    final sourceUri = file is SourceDocxFile ? file.sourceUri : null;
    if (file.name.toLowerCase().endsWith('.pdf')) {
      final pdf = await _documents.storePdf(
        file.name,
        bytes,
        sourceUri: sourceUri,
      );
      await _recovery.clear(_currentDocument.id);
      if (!mounted) return;
      _checkpointTimer?.cancel();
      setState(() => _allowPop = true);
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(builder: (_) => PdfViewerPage(document: pdf)),
        ),
      );
      return;
    }
    final document = await _documents.storeOffice(
      file.name,
      bytes,
      sourceUri: sourceUri,
      legacyDoc: file.name.toLowerCase().endsWith('.doc'),
      format:
          editableFormat(file.name) ??
          (throw StateError('Định dạng không hỗ trợ.')),
    );
    if (document.format != widget.document.format) {
      await _recovery.clear(_currentDocument.id);
      if (!mounted) return;
      _checkpointTimer?.cancel();
      setState(() => _allowPop = true);
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(
            builder: (_) => MobileDocxEditorPage(
              document: document,
              documents: _documents,
              recoveryStore: _recovery,
            ),
          ),
        ),
      );
      return;
    }
    final previousId = _currentDocument.id;
    if (!await _loadDocument(
      document,
      sourceBytes: bytes,
      ignoreRecovery: document.id == previousId,
    )) {
      return;
    }
    await _recovery.clear(previousId);
    if (mounted) setState(() {});
  });
  Future<void> _leave() async {
    if (_working) return;
    setState(() => _busy = true);
    try {
      if (!await _confirmDiscard()) return;
      await _recovery.clear(_currentDocument.id);
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Không kiểm tra được thay đổi: $error');
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) {
      _checkpointTimer?.cancel();
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkpointTimer?.cancel();
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
            tooltip: 'Mở tài liệu',
            onPressed: _working || _error != null ? null : _pick,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            key: const Key('save-docx'),
            tooltip: 'Lưu',
            onPressed: _working || _error != null
                ? null
                : () => _perform(() async {
                    await _bridge!.save();
                  }),
            icon: const Icon(Icons.save_outlined),
          ),
          PopupMenuButton<String>(
            key: const Key('document-actions'),
            tooltip: 'Thêm',
            enabled: !_working && _error == null,
            onSelected: (_) => _perform(() async {
              await _bridge!.saveAs();
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'saveAs',
                child: ListTile(
                  leading: Icon(Icons.save_as_outlined),
                  title: Text('Lưu thành bản mới'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
