import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../domain/editor_document.dart';

typedef PersistEditorExport =
    Future<EditorSaveResult> Function(String name, Uint8List bytes);

/// Serves only bundled assets and one document, on loopback and a random path.
/// No arbitrary filesystem paths, remote fetching or JS evaluation endpoint.
class EditorAssetServer {
  EditorAssetServer({
    required this.persistExport,
    this.persistCopy,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;
  static const maxDocumentBytes = 20 * 1024 * 1024;
  static const maxExportBytes = 32 * 1024 * 1024;
  final PersistEditorExport persistExport;
  final PersistEditorExport? persistCopy;
  final AssetBundle _bundle;
  HttpServer? _server;
  late Uri _base;
  EditorDocument? _document;
  String? _documentKey;
  bool _saving = false;
  EditorSaveResult? lastSave;
  int saveRevision = 0;
  final _saved = StreamController<EditorSaveResult>.broadcast();
  Stream<EditorSaveResult> get saved => _saved.stream;
  Uri get editorUri => _base.resolve('index.html?mobile=1');
  Uri get baseUri => _base;

  Future<void> start() async {
    if (_server != null) throw StateError('Server already started');
    final token = List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _base = Uri.parse('http://127.0.0.1:${server.port}/$token/');
    server.listen((request) => unawaited(_handle(request)));
  }

  Uri provideDocument(EditorDocument document) {
    // Native imports remain limited to 20 MB. A saved document can grow to
    // the export limit and must still be reopenable from the library.
    if (document.bytes.length > maxExportBytes) {
      throw ArgumentError('DOCX vượt giới hạn 32 MB');
    }
    if (!document.name.toLowerCase().endsWith('.docx')) {
      throw ArgumentError('Chỉ hỗ trợ DOCX');
    }
    _document = document;
    _documentKey = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return _base.resolve('documents/$_documentKey');
  }

  bool allowsNavigation(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.origin == _base.origin &&
        uri.path == editorUri.path &&
        uri.query == editorUri.query;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    try {
      if (request.headers.value(HttpHeaders.hostHeader) != _base.authority ||
          !request.uri.path.startsWith(_base.path)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final path = request.uri.path.substring(_base.path.length);
      if (path == 'exports' && request.method == 'POST') {
        if (request.headers.value('origin') != _base.origin) {
          response.statusCode = HttpStatus.forbidden;
          return;
        }
        if (_saving) {
          response.statusCode = HttpStatus.conflict;
          return;
        }
        if (request.contentLength > maxExportBytes) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          return;
        }
        _saving = true;
        try {
          final builder = BytesBuilder(copy: false);
          await for (final chunk in request) {
            if (builder.length + chunk.length > maxExportBytes) {
              response.statusCode = HttpStatus.requestEntityTooLarge;
              return;
            }
            builder.add(chunk);
          }
          final bytes = builder.takeBytes();
          if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
            throw const FormatException('Invalid DOCX export');
          }
          final raw = request.uri.queryParameters['name'] ?? 'document.docx';
          final name = raw
              .replaceAll(RegExp(r'[^a-zA-Z0-9À-ỹ ._()-]'), '_')
              .replaceAll(RegExp(r'^\.+'), '');
          final persist = request.uri.queryParameters['mode'] == 'copy'
              ? (persistCopy ?? persistExport)
              : persistExport;
          final result = await persist(
            name.toLowerCase().endsWith('.docx') ? name : '$name.docx',
            bytes,
          );
          lastSave = result;
          saveRevision++;
          _saved.add(result);
          response.headers.contentType = ContentType.json;
          response.write(
            jsonEncode({'ok': true, 'name': result.name, 'path': result.path}),
          );
        } finally {
          _saving = false;
        }
        return;
      }
      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (path == 'documents/$_documentKey' && _document != null) {
        response.headers.contentType = ContentType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
        response.add(_document!.bytes);
        return;
      }
      if (path.startsWith('documents/') ||
          path.isEmpty ||
          path.split('/').any((part) => part == '.' || part == '..') ||
          path.contains('\\')) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final data = await _bundle.load('assets/editor/$path');
      response.headers.contentType = _contentType(path);
      response.add(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'ok': false,
          'error': 'Không đọc hoặc ghi được dữ liệu editor.',
        }),
      );
    } finally {
      await response.close();
    }
  }

  static ContentType _contentType(String path) {
    if (path.endsWith('.html')) return ContentType.html;
    if (path.endsWith('.js') || path.endsWith('.mjs')) {
      return ContentType('text', 'javascript', charset: 'utf-8');
    }
    if (path.endsWith('.css')) {
      return ContentType('text', 'css', charset: 'utf-8');
    }
    if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
    if (path.endsWith('.ttf')) return ContentType('font', 'ttf');
    if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (path.endsWith('.json')) return ContentType.json;
    return ContentType.binary;
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
    _document = null;
    await _saved.close();
  }
}
