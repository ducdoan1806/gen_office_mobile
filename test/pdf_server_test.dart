import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/editor/data/editor_asset_server.dart';
import 'package:gen_office_mobile/features/editor/domain/editor_document.dart';

void main() {
  test('PDF endpoint is scoped, serves PDF and rejects writing', () async {
    final bytes = await File(
      'assets/samples/pdf-viewer-test.pdf',
    ).readAsBytes();
    final server = EditorAssetServer(
      pdf: true,
      persistExport: (_, _) async => throw StateError('Must never write PDF'),
    );
    await server.start();
    addTearDown(server.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final url = server.provideDocument(
      EditorDocument(id: 'test', name: 'test.pdf', bytes: bytes),
    );
    final response = await (await client.getUrl(url)).close();
    expect(response.headers.contentType!.mimeType, 'application/pdf');
    expect(await response.expand((chunk) => chunk).toList(), bytes);
    expect(server.allowsNavigation(server.editorUri.toString()), isTrue);
    expect(server.allowsNavigation('https://example.com'), isFalse);
    final wrong = await (await client.getUrl(
      url.replace(path: '/wrong/documents/test'),
    )).close();
    expect(wrong.statusCode, 403);
    await wrong.drain<void>();
    final post = await client.postUrl(server.baseUri.resolve('exports'));
    post.headers.set('origin', server.baseUri.origin);
    final denied = await post.close();
    expect(denied.statusCode, 405);
    await denied.drain<void>();
    expect(server.saveRevision, 0);
  });
}
