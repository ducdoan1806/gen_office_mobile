import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/editor/data/editor_asset_server.dart';
import 'package:gen_office_mobile/features/editor/domain/editor_document.dart';

void main() {
  test(
    'recovery has origin checks, failure retry and never acknowledges a manual save',
    () async {
      var exports = 0, snapshots = 0;
      var fail = true;
      final client = HttpClient();
      final server = EditorAssetServer(
        persistExport: (name, bytes) async {
          exports++;
          return EditorSaveResult(name: name, path: '/source');
        },
        persistRecovery: (id, bytes) async {
          expect(id, 'doc-A');
          expect(bytes, [80, 75, 3, 4, 1]);
          if (fail) throw FileSystemException('Simulated full disk');
          snapshots++;
        },
      );
      await server.start();
      addTearDown(() async {
        client.close(force: true);
        await server.close();
      });
      Future<HttpClientResponse> post({
        bool origin = true,
        String id = 'doc-A',
        List<int> bytes = const [80, 75, 3, 4, 1],
      }) async {
        final request = await client.postUrl(
          server.baseUri.resolve('recovery?documentId=$id'),
        );
        if (origin) request.headers.set('origin', server.baseUri.origin);
        request.add(bytes);
        return request.close();
      }

      final denied = await post(origin: false);
      expect(denied.statusCode, 403);
      await denied.drain<void>();
      final failed = await post();
      expect(failed.statusCode, 500);
      await failed.drain<void>();
      expect(server.saveRevision, 0);
      fail = false;
      final accepted = await post();
      expect(accepted.statusCode, 200);
      expect(jsonDecode(await utf8.decoder.bind(accepted).join()), {
        'ok': true,
      });
      expect(snapshots, 1);
      expect(exports, 0);
      expect(server.lastSave, isNull);
      expect(server.saveRevision, 0);
      final invalid = await post(bytes: [0, 0, 0, 0]);
      expect(invalid.statusCode, 500);
      await invalid.drain<void>();
      final missing = await post(id: '');
      expect(missing.statusCode, 500);
      await missing.drain<void>();
      expect(snapshots, 1);
    },
  );
  test(
    'unconfigured recovery endpoint never falls back to the source save handler',
    () async {
      var exports = 0;
      final server = EditorAssetServer(
        persistExport: (name, bytes) async {
          exports++;
          return EditorSaveResult(name: name, path: '/source');
        },
      );
      final client = HttpClient();
      await server.start();
      addTearDown(() async {
        client.close(force: true);
        await server.close();
      });
      final request = await client.postUrl(
        server.baseUri.resolve('recovery?documentId=doc'),
      );
      request.headers.set('origin', server.baseUri.origin);
      request.add([80, 75, 3, 4]);
      final response = await request.close();
      expect(response.statusCode, 404);
      await response.drain<void>();
      expect(exports, 0);
    },
  );
}
