import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../domain/document_editor_bridge.dart';
import '../domain/editor_document.dart';
import 'editor_asset_server.dart';

class WebViewDocumentEditorBridge implements DocumentEditorBridge {
  WebViewDocumentEditorBridge({required this.server});
  final EditorAssetServer server;
  late final WebViewController controller;
  final ready = Completer<void>();
  final _pending = <String, Completer<Object?>>{};
  final error = ValueNotifier<String?>(null);
  VoidCallback? onPickDocument;
  int _sequence = 0;
  bool _closed = false;

  Future<void> initialize() async {
    await server.start();
    if (_closed) {
      await server.close();
      return;
    }
    controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.enableZoom(true);
    await controller.addJavaScriptChannel(
      'GenOfficeHost',
      onMessageReceived: (message) => handleMessage(message.message),
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) => server.allowsNavigation(request.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onWebResourceError: (event) {
          if (event.isForMainFrame == true) error.value = event.description;
        },
      ),
    );
    await controller.loadRequest(server.editorUri);
  }

  @visibleForTesting
  void handleMessage(String raw) {
    if (_closed) return;
    try {
      final message = jsonDecode(raw) as Map<String, dynamic>;
      if (message['type'] == 'ready') {
        if (!ready.isCompleted) ready.complete();
        return;
      }
      if (message['type'] == 'error') {
        error.value = message['error']?.toString();
        return;
      }
      if (message['type'] == 'pickDocument') {
        onPickDocument?.call();
        return;
      }
      if (message['type'] == 'confirmRequired') {
        error.value =
            'Dùng nút mở tài liệu trên thanh Flutter để thay tài liệu.';
        return;
      }
      if (message['type'] != 'reply') return;
      final pending = _pending.remove(message['id']);
      if (pending == null) return;
      message['ok'] == true
          ? pending.complete(message['value'])
          : pending.completeError(
              StateError(
                message['error']?.toString() ?? 'Editor command failed',
              ),
            );
    } catch (_) {
      error.value = 'Thông điệp từ editor không hợp lệ.';
    }
  }

  Future<Object?> _command(String method, [Map<String, Object?>? args]) async {
    if (_closed) throw StateError('Editor is closed');
    await ready.future.timeout(const Duration(seconds: 45));
    if (_closed) throw StateError('Editor is closed');
    final id = 'command-${++_sequence}';
    final completer = Completer<Object?>();
    _pending[id] = completer;
    final payload = jsonEncode({'id': id, 'method': method, 'args': args});
    // Payload is serialized JSON data, never interpolated executable source.
    final response = completer.future.timeout(
      Duration(seconds: method == 'save' ? 600 : 50),
    );
    try {
      try {
        await controller.runJavaScript(
          'void window.genOfficeMobile.receive($payload);',
        );
      } catch (error) {
        if (!completer.isCompleted) completer.completeError(error);
      }
      return await response;
    } finally {
      _pending.remove(id);
    }
  }

  @override
  Future<void> open(EditorDocument document) async {
    final url = server.provideDocument(document);
    await _command('open', {
      'documentId': document.id,
      'name': document.name,
      'url': url.toString(),
    });
  }

  @override
  Future<EditorSaveResult> save() async {
    final revision = server.saveRevision;
    await _command('save');
    if (server.saveRevision == revision || server.lastSave == null) {
      throw StateError('Không nhận được DOCX đã lưu');
    }
    return server.lastSave!;
  }

  @override
  Future<void> undo() async {
    await _command('undo');
  }

  @override
  Future<void> redo() async {
    await _command('redo');
  }

  @override
  Future<bool> hasUnsavedChanges() async =>
      ((await _command('status')) as Map)['dirty'] == true;
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final pending in _pending.values) {
      pending.completeError(StateError('Editor closed'));
    }
    _pending.clear();
    await server.close();
    error.dispose();
  }
}
