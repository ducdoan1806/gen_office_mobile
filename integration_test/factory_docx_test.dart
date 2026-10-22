import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gen_office_mobile/features/documents/data/local_document_repository.dart';
import 'package:gen_office_mobile/features/editor/data/editor_asset_server.dart';
import 'package:gen_office_mobile/features/editor/data/webview_document_editor_bridge.dart';
import 'package:gen_office_mobile/features/editor/domain/editor_document.dart';
import 'package:gen_office_mobile/features/editor/presentation/mobile_docx_editor_page.dart';

/// Optional private corpus, served over adb reverse. Documents are never bundled
/// into the app or committed to source control.
const corpusUrl = String.fromEnvironment('GENOFFICE_TEST_CORPUS_URL');

String stableCoreProperties(List<int> bytes) => utf8
    .decode(bytes)
    .replaceAllMapped(
      RegExp(r'(<dcterms:modified\b[^>]*>)[^<]*(</dcterms:modified>)'),
      (match) => '${match[1]}[save-time]${match[2]}',
    )
    .replaceAllMapped(
      RegExp(r'(<cp:revision>)[^<]*(</cp:revision>)'),
      (match) => '${match[1]}[save-revision]${match[2]}',
    );

// Keep native platform views and WebView layout advancing during large exports.
Future<T> withFrames<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async {
  var done = false;
  T? result;
  Object? failure;
  StackTrace? stack;
  await tester.runAsync(() async {
    action().then(
      (value) {
        result = value;
        done = true;
      },
      onError: (Object error, StackTrace trace) {
        failure = error;
        stack = trace;
        done = true;
      },
    );
  });
  for (var attempt = 0; attempt < 1800 && !done; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  if (!done) {
    throw StateError('Corpus operation timed out while pumping WebView frames');
  }
  if (failure != null) Error.throwWithStackTrace(failure!, stack!);
  return result as T;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'private DOCX corpus preserves untouched parts and edited content',
    (tester) async {
      final client = HttpClient();
      addTearDown(client.close);
      final directory = await (await getTemporaryDirectory()).createTemp(
        'factory-corpus-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final manifestResponse = await (await client.getUrl(
        Uri.parse('$corpusUrl/manifest'),
      )).close();
      expect(manifestResponse.statusCode, HttpStatus.ok);
      final manifest =
          jsonDecode(await utf8.decoder.bind(manifestResponse).join())
              as List<dynamic>;
      expect(manifest, isNotEmpty);
      for (var index = 0; index < manifest.length; index++) {
        final name =
            (manifest[index] as Map<String, dynamic>)['name'] as String;
        final response = await (await client.getUrl(
          Uri.parse('$corpusUrl/files/$index'),
        )).close();
        expect(response.statusCode, HttpStatus.ok);
        final source = await response.fold<List<int>>(
          <int>[],
          (bytes, chunk) => bytes..addAll(chunk),
        );
        final originalZip = ZipDecoder().decodeBytes(source);
        final repository = LocalDocumentRepository(
          documentsDirectory: () async => Directory('${directory.path}/$index'),
        );
        final imported = await repository.storeDocx(
          name,
          Uint8List.fromList(source),
        );
        final bridge = WebViewDocumentEditorBridge(
          server: EditorAssetServer(
            persistExport: (name, bytes) async {
              final saved = await repository.storeDocx(
                name,
                bytes,
                isExport: true,
              );
              return EditorSaveResult(name: saved.name, path: saved.filePath!);
            },
          ),
        );
        final ready = Completer<void>();
        await tester.pumpWidget(
          MaterialApp(
            home: MobileDocxEditorPage(
              document: imported,
              documents: repository,
              bridge: bridge,
              onReady: () {
                if (!ready.isCompleted) ready.complete();
              },
            ),
          ),
        );
        for (var attempt = 0; attempt < 600 && !ready.isCompleted; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        }
        expect(ready.isCompleted, true, reason: 'Open corpus document $name');
        debugPrint('CORPUS OPEN: $name');

        final unchanged = await withFrames(tester, bridge.save);
        final unchangedZip = ZipDecoder().decodeBytes(
          await File(unchanged.path).readAsBytes(),
        );
        for (final entry in originalZip.files.where((entry) => entry.isFile)) {
          expect(
            sha256
                .convert(
                  unchangedZip.findFile(entry.name)!.content as List<int>,
                )
                .toString(),
            sha256.convert(entry.content as List<int>).toString(),
            reason: 'Unedited $name: ${entry.name}',
          );
        }
        debugPrint('CORPUS UNCHANGED SAVE: $name');
        final marker = ' — GenOffice QA ${index + 1}';
        await bridge.controller.runJavaScript('''
          (() => {
            const paragraph = [...document.querySelectorAll('.ProseMirror p')].find(p => p.textContent.trim());
            if (!paragraph) throw new Error('No editable paragraph');
            paragraph.closest('[contenteditable]').focus();
            const range = document.createRange(); range.selectNodeContents(paragraph); range.collapse(false);
            const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
            document.execCommand('insertText', false, ${jsonEncode(marker)});
          })();
        ''');
        final saved = await withFrames(tester, bridge.save);
        final bytes = await File(saved.path).readAsBytes();
        final editedZip = ZipDecoder().decodeBytes(bytes);
        final xml = utf8.decode(
          editedZip.findFile('word/document.xml')!.content as List<int>,
        );
        expect(xml, contains(marker), reason: name);
        // Text editing must not change embedded images, styles, relationships,
        // headers/footers or other untouched OOXML parts.
        for (final entry in originalZip.files.where(
          (entry) => entry.isFile && entry.name != 'word/document.xml',
        )) {
          if (entry.name == 'docProps/core.xml') {
            expect(
              stableCoreProperties(
                editedZip.findFile(entry.name)!.content as List<int>,
              ),
              stableCoreProperties(entry.content as List<int>),
              reason: 'Core properties $name',
            );
            continue;
          }
          expect(
            sha256
                .convert(editedZip.findFile(entry.name)!.content as List<int>)
                .toString(),
            sha256.convert(entry.content as List<int>).toString(),
            reason: 'Edited $name: ${entry.name}',
          );
        }
        expect(
          sha256
              .convert(await File(imported.filePath!).readAsBytes())
              .toString(),
          sha256.convert(source).toString(),
          reason: 'Original $name',
        );
        debugPrint('CORPUS EDITED SAVE: $name');
        await withFrames(
          tester,
          () => bridge.open(
            EditorDocument(id: 'reopened-$index', name: name, bytes: bytes),
          ),
        );
        final text = await bridge.controller.runJavaScriptReturningResult(
          "document.querySelector('.ProseMirror').textContent",
        );
        expect(text.toString(), contains(marker), reason: name);
        expect(bridge.error.value, isNull, reason: name);
        final upload = await client.postUrl(
          Uri.parse('$corpusUrl/results/$index'),
        );
        upload.add(bytes);
        final uploadResponse = await upload.close();
        expect(uploadResponse.statusCode, HttpStatus.ok);
        await uploadResponse.drain<void>();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        // One concise result per private file; no document contents in logs.
        debugPrint('CORPUS PASS: $name');
      }
    },
    skip: corpusUrl.isEmpty,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
