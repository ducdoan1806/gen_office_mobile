import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/editor/data/editor_asset_server.dart';
import 'package:gen_office_mobile/features/editor/domain/editor_document.dart';

class TestBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/editor/index.html') throw StateError('Missing asset');
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode('<html>editor</html>')),
    );
  }
}

void main() {
  late EditorAssetServer server;
  late HttpClient client;
  int saves = 0;
  setUp(() async {
    saves = 0;
    client = HttpClient();
    server = EditorAssetServer(
      bundle: TestBundle(),
      persistExport: (name, bytes) async {
        saves++;
        return EditorSaveResult(name: name, path: '/app/exports/$name');
      },
    );
    await server.start();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });
  test('serves assets/documents only under its private session path', () async {
    final response = await (await client.getUrl(server.editorUri)).close();
    expect(response.statusCode, 200);
    expect(await utf8.decoder.bind(response).join(), contains('editor'));
    final forbidden = await (await client.getUrl(
      server.baseUri.resolve('/index.html'),
    )).close();
    expect(forbidden.statusCode, 403);
    await forbidden.drain<void>();
    final url = server.provideDocument(
      EditorDocument(
        id: 'sample',
        name: 'sample.docx',
        bytes: Uint8List.fromList([80, 75, 3, 4]),
      ),
    );
    final document = await (await client.getUrl(url)).close();
    expect(
      await document.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
      [80, 75, 3, 4],
    );
    expect(server.allowsNavigation(server.editorUri.toString()), true);
    expect(server.allowsNavigation('https://example.com'), false);
    expect(server.allowsNavigation('javascript:alert(1)'), false);
  });
  test(
    'persists export before acknowledging and rejects cross-origin writes',
    () async {
      final request = await client.postUrl(
        server.baseUri.resolve('exports?name=factory.docx'),
      );
      request.add([80, 75, 3, 4]);
      final denied = await request.close();
      expect(denied.statusCode, 403);
      await denied.drain<void>();
      expect(saves, 0);
      final valid = await client.postUrl(
        server.baseUri.resolve('exports?name=factory.docx'),
      );
      valid.headers.set('origin', server.baseUri.origin);
      valid.add([80, 75, 3, 4]);
      final response = await valid.close();
      final result = jsonDecode(await utf8.decoder.bind(response).join());
      expect(result['ok'], true);
      expect(result['path'], '/app/exports/factory.docx');
      expect(saves, 1);
      expect(server.saveRevision, 1);
    },
  );
}
