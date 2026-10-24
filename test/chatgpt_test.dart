import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/ai/data/ai_document_edit.dart';
import 'package:gen_office_mobile/features/ai/data/oauth_return_page.dart';
import 'package:gen_office_mobile/features/ai/data/chatgpt_client.dart';
import 'package:gen_office_mobile/features/ai/presentation/document_ai_sheet.dart';

class LoopbackHttpOverrides extends HttpOverrides {}

class FakeChatGpt extends ChatGptClient {
  final stream = StreamController<String>.broadcast();
  final sent = <List<Map<String, String>>>[];
  String identity = 'one';
  @override
  bool get connected => true;
  @override
  String? get subject => identity;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> loadModels() async {}
  @override
  Stream<String> reply(
    List<Map<String, String>> history, {
    required HttpClient transport,
    String? modelId,
  }) {
    sent.add(history);
    return stream.stream;
  }

  void changed() => notifyListeners();
}

class ScriptedChatGpt extends FakeChatGpt {
  final responses = <String>[];
  @override
  Stream<String> reply(
    List<Map<String, String>> history, {
    required HttpClient transport,
    String? modelId,
  }) {
    sent.add(history);
    return Stream.value(responses.removeAt(0));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'edit proposal rejects invented targets, stale text and duplicate changes',
    () {
      final context = <String, dynamic>{
        'revision': 'r1',
        'entries': [
          {'id': 'p1', 'label': 'P1', 'text': 'Original'},
        ],
      };
      String proposal(List<Map<String, String>> changes) =>
          jsonEncode({'summary': 'Sửa', 'changes': changes});
      final edit = AiDocumentEdit.parse(
        proposal([
          {'id': 'p1', 'before': 'Original', 'after': 'Changed'},
        ]),
        context,
      );
      expect(edit.payload['revision'], 'r1');
      expect(edit.changes.single['after'], 'Changed');
      for (final changes in [
        [
          {'id': 'unknown', 'before': 'Original', 'after': 'Changed'},
        ],
        [
          {'id': 'p1', 'before': 'Wrong', 'after': 'Changed'},
        ],
        [
          {'id': 'p1', 'before': 'Original', 'after': 'A'},
          {'id': 'p1', 'before': 'Original', 'after': 'B'},
        ],
      ]) {
        expect(
          () => AiDocumentEdit.parse(proposal(changes), context),
          throwsFormatException,
        );
      }
      expect(
        () => AiDocumentEdit.parse('not json', context),
        throwsFormatException,
      );
    },
  );
  test('callback auto returns and exposes fallback only after countdown', () {
    final success = oauthReturnPage(success: true, nonce: 'test-nonce');
    expect(success, contains('nonce="test-nonce"'));
    expect(success, contains('let left=5'));
    expect(
      success,
      contains('window.location.href="vpic1office://chatgpt-return"'),
    );
    expect(success, contains('chatgpt-return" hidden'));
    final denied = oauthReturnPage(success: false, nonce: 'test-nonce');
    expect(denied, isNot(contains('<script')));
    expect(denied, isNot(contains('Đã kết nối ChatGPT')));
  });
  testWidgets(
    'AI sheet fits small screen and multiline keyboard without overflow',
    (tester) async {
      final client = FakeChatGpt()
        ..model = 'test'
        ..models = [const ChatGptModel('test', 'Test')];
      final chat = DocumentChat(client: client);
      chat.readDocument = () async => {};
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDocumentAi(context, chat, 'Test.docx'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        true,
      );
      chat.input.text = 'Line1\nLine2\nLine3\nLine4';
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('send-ai')), findsOneWidget);
      tester.view.physicalSize = const Size(360, 480);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      chat.dispose();
      client.dispose();
    },
  );
  testWidgets(
    'sending immediately shows acknowledgement through slow context and first response',
    (tester) async {
      final api = FakeChatGpt()
        ..model = 'first'
        ..models = [const ChatGptModel('first', 'Test')];
      final chat = DocumentChat(client: api);
      await chat.initialize();
      final context = Completer<Map<String, dynamic>>();
      chat.readDocument = () => context.future;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDocumentAi(context, chat, 'Sample.docx'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      chat.input.text = 'Summarize';
      await tester.tap(find.byKey(const Key('send-ai')));
      await tester.pump();
      expect(chat.messages.first.text, 'Summarize');
      expect(chat.input.text, isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Summarize'), findsOneWidget);
      expect(find.byKey(const Key('ai-waiting')), findsOneWidget);
      expect(find.text('Đã nhận yêu cầu · Đang đọc tài liệu…'), findsOneWidget);
      expect(api.sent, isEmpty);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('ai-waiting')), findsOneWidget);
      context.complete({
        'revision': 'r',
        'scope': 'Word',
        'entries': [
          {'id': '1', 'label': 'P1', 'text': 'Sample'},
        ],
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Đã nhận yêu cầu · Đang chờ ChatGPT…'), findsOneWidget);
      expect(api.sent, hasLength(1));
      api.stream.add('{"summary":"Done","changes":[]}');
      await tester.pump();
      expect(find.text('AI đang trả lời…'), findsOneWidget);
      await api.stream.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Done'), findsOneWidget);
      expect(find.byKey(const Key('ai-waiting')), findsNothing);
      expect(chat.phase, isNull);
      expect(chat.busy, false);
      expect(chat.messages.first.complete, true);
      await tester.pumpWidget(const SizedBox());
      chat.dispose();
      api.dispose();
    },
  );
  test(
    'stop during document read clears progress and ignores late results',
    () async {
      final api = FakeChatGpt()..model = 'first';
      final chat = DocumentChat(client: api);
      await chat.initialize();
      final context = Completer<Map<String, dynamic>>();
      chat.readDocument = () => context.future;
      chat.input.text = 'Question';
      final task = chat.send();
      expect(chat.phase, AiRequestPhase.readingDocument);
      expect(chat.messages.first.text, 'Question');
      chat.stop();
      chat.input.text = 'New draft';
      context.complete({'revision': 'r', 'entries': []});
      await task;
      expect(api.sent, isEmpty);
      expect(chat.busy, false);
      expect(chat.phase, isNull);
      expect(chat.messages.last.text, 'Đã dừng yêu cầu.');
      expect(chat.input.text, 'New draft');
      chat.dispose();
      await api.stream.close();
      api.dispose();
    },
  );
  test(
    'current document is automatic and edits apply only on explicit action',
    () async {
      final client = FakeChatGpt()
        ..model = 'test'
        ..models = [const ChatGptModel('test', 'Test')];
      final chat = DocumentChat(client: client);
      await chat.initialize();
      var applied = 0;
      chat.readDocument = () async => {
        'revision': 'r1',
        'scope': 'Word',
        'entries': [
          {'id': '1', 'label': 'Đoạn 1', 'text': 'Old'},
        ],
      };
      chat.applyDocument = (payload) async {
        expect(payload['revision'], 'r1');
        applied++;
      };
      chat.input.text = 'Rewrite';
      final pending = chat.send();
      await Future<void>.delayed(Duration.zero);
      client.stream.add(
        '{"summary":"Updated", "changes":[{"id":"1","before":"Old","after":"New"}]}',
      );
      await Future<void>.delayed(Duration.zero);
      expect(applied, 0);
      expect(chat.messages.last.complete, false);
      await client.stream.close();
      await pending;
      final edit = chat.messages.last.edit!;
      expect(edit.applied, false);
      expect(applied, 0);
      await chat.applyEdit(edit);
      expect(applied, 1);
      expect(edit.applied, true);
      await chat.applyEdit(edit);
      expect(applied, 1);
      chat.dispose();
      client.dispose();
    },
  );
  test(
    'questions use fresh open-file content automatically, without proposing edits',
    () async {
      final client = ScriptedChatGpt()
        ..model = 'test'
        ..models = [const ChatGptModel('test', 'Test')];
      client.responses.addAll([
        '{"summary":"Summary of Old","changes":[]}',
        '{"summary":"Summary of Unsaved","changes":[]}',
      ]);
      final chat = DocumentChat(client: client);
      await chat.initialize();
      var text = 'Old';
      var calls = 0;
      chat.documentName = 'Report.docx';
      chat.readDocument = () async {
        calls++;
        return {
          'revision': 'r$calls',
          'scope': 'Word',
          'entries': [
            {'id': '1', 'label': 'Đoạn 1', 'text': text},
          ],
        };
      };
      chat.applyDocument = (_) async =>
          fail('A question must never apply edits');
      chat.attachment = 'Extra note';
      chat.input.text = 'Summarize this file';
      await chat.send();
      expect(client.sent.single.last['content'], contains('Old'));
      expect(client.sent.single.last['content'], contains('Report.docx'));
      expect(client.sent.single.last['content'], contains('Extra note'));
      expect(chat.messages.last.text, 'Summary of Old');
      expect(chat.messages.last.edit, isNull);
      text = 'Unsaved';
      chat.input.text = 'What changed?';
      await chat.send();
      expect(calls, 2);
      expect(client.sent.last.last['content'], contains('Unsaved'));
      expect(chat.messages.last.text, 'Summary of Unsaved');
      expect(chat.messages.last.edit, isNull);
      chat.dispose();
      client.dispose();
    },
  );
  test(
    'context failure does not silently send a question without the file',
    () async {
      final client = ScriptedChatGpt()
        ..model = 'test'
        ..models = [const ChatGptModel('test', 'Test')];
      final chat = DocumentChat(client: client);
      await chat.initialize();
      chat.readDocument = () async => throw StateError('File not ready');
      chat.input.text = 'Summarize';
      await chat.send();
      expect(client.sent, isEmpty);
      expect(chat.input.text, 'Summarize');
      expect(chat.error, contains('File not ready'));
      expect(chat.phase, isNull);
      expect(chat.busy, false);
      chat.dispose();
      client.dispose();
    },
  );
  test(
    'PDF context is automatically included and cannot propose editable changes',
    () async {
      final client = ScriptedChatGpt()
        ..model = 'test'
        ..models = [const ChatGptModel('test', 'Test')];
      client.responses.addAll([
        '{"summary":"Page summary","changes":[]}',
        '{"summary":"Edit","changes":[{"id":"1","before":"PDF text","after":"Changed"}]}',
      ]);
      final chat = DocumentChat(client: client);
      await chat.initialize();
      chat.readDocument = () async => {
        'revision': 'pdf',
        'scope': 'PDF',
        'entries': [
          {'id': '1', 'label': 'Page 1', 'text': 'PDF text'},
        ],
      };
      chat.input.text = 'Summarize';
      await chat.send();
      expect(client.sent.single.last['content'], contains('"editable":false'));
      expect(chat.messages.last.text, 'Page summary');
      chat.input.text = 'Change';
      await chat.send();
      expect(chat.messages.last.edit, isNull);
      expect(chat.error, contains('chỉ đọc'));
      chat.dispose();
      client.dispose();
    },
  );
  test(
    'restarting after process death detects interrupted login and preserves host identity',
    () async {
      const channel = MethodChannel('chatgpt-recovery-test');
      String? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'read') {
              return jsonEncode({
                'host_id': 'urn:uuid:stable-host',
                'auth_pending': true,
              });
            }
            if (call.method == 'write') {
              saved = (call.arguments as Map)['value'] as String;
              return null;
            }
            throw StateError('Unexpected method');
          });
      final client = ChatGptClient(platform: channel);
      final chat = DocumentChat(client: client);
      try {
        await chat.initialize();
        expect(client.interruptedAuth, true);
        expect(client.connected, false);
        expect(chat.error, contains('Android đã dừng'));
        final record = jsonDecode(saved!) as Map;
        expect(record['host_id'], 'urn:uuid:stable-host');
        expect(record.containsKey('auth_pending'), false);
      } finally {
        chat.dispose();
        client.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );
  test(
    'OAuth rejects forged state and handles valid denied callback without saving tokens',
    () async {
      const channel = MethodChannel('chatgpt-oauth-test');
      final writes = <String>[];
      final callbackDone = Completer<void>();
      final http = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        LoopbackHttpOverrides(),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'read' || call.method == 'closeBrowser') {
              return null;
            }
            if (call.method == 'write') {
              writes.add((call.arguments as Map)['value'] as String);
              return null;
            }
            if (call.method == 'openBrowser') {
              final authorization = Uri.parse(
                (call.arguments as Map)['url'] as String,
              );
              final redirect = Uri.parse(
                authorization.queryParameters['redirect_uri']!,
              );
              expect(redirect.host, '127.0.0.1');
              final forged = await http.getUrl(
                redirect.replace(
                  queryParameters: {
                    'state': 'forged',
                    'error': 'access_denied',
                  },
                ),
              );
              final rejected = await forged.close();
              expect(rejected.statusCode, 400);
              await rejected.drain<void>();
              final denied = await http.getUrl(
                redirect.replace(
                  queryParameters: {
                    'state': authorization.queryParameters['state']!,
                    'error': 'access_denied',
                  },
                ),
              );
              unawaited(
                denied
                    .close()
                    .then((accepted) async {
                      expect(accepted.statusCode, 200);
                      final html = await accepted
                          .transform(utf8.decoder)
                          .join();
                      expect(html, contains('Chưa hoàn tất đăng nhập'));
                      expect(html, isNot(contains('Đã kết nối ChatGPT')));
                      callbackDone.complete();
                    })
                    .catchError((Object e, StackTrace st) {
                      callbackDone.completeError(e, st);
                    }),
              );
              return null;
            }
            throw StateError('Unexpected platform method');
          });
      final client = ChatGptClient(platform: channel);
      try {
        await expectLater(client.connect(), throwsA(isA<ChatGptException>()));
        await callbackDone.future;
        expect(client.connected, false);
        expect(client.connecting, false);
        expect(writes.every((s) => !s.contains('access_token')), true);
      } finally {
        http.close(force: true);
        client.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );
  test(
    'PKCE matches RFC7636 and OAuth requests plan permission, state, nonce',
    () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      expect(
        ChatGptClient.challenge(verifier),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
      final uri = ChatGptClient.authorizationUri(
        host: 'urn:uuid:host',
        state: 'random-state',
        nonce: 'random-nonce',
        verifier: verifier,
        redirect: 'http://127.0.0.1:4123/auth/callback',
      );
      expect(uri.host, 'auth.openai.com');
      expect(uri.queryParameters['client_id'], 'dynamic_agent_client');
      expect(uri.queryParameters['state'], 'random-state');
      expect(uri.queryParameters['nonce'], 'random-nonce');
      expect(
        uri.queryParameters['scope'],
        contains('chatgpt.tokens.use.direct'),
      );
      final returning = ChatGptClient.authorizationUri(
        host: 'urn:uuid:host',
        state: 's',
        nonce: 'n',
        verifier: verifier,
        redirect: 'http://127.0.0.1:4123/auth/callback',
        clientId: 'oaiapp_saved',
      );
      expect(returning.queryParameters['client_id'], 'oaiapp_saved');
      expect(returning.queryParameters.containsKey('agent_name_hint'), false);
    },
  );
  test(
    'Responses request avoids unsupported plan-usage fields and server storage',
    () {
      final body = ChatGptClient.requestBody('chosen-model', [
        {'role': 'user', 'content': 'Xin chào'},
      ]);
      expect(body['model'], 'chosen-model');
      expect(body['store'], false);
      expect(body['stream'], true);
      expect(body.containsKey('previous_response_id'), false);
      expect(body.containsKey('max_output_tokens'), false);
      expect((body['input'] as List).single, {
        'role': 'user',
        'content': 'Xin chào',
      });
    },
  );
  test(
    'SSE decodes fragmented UTF8, CRLF, comments and multiple events',
    () async {
      final text =
          ': heartbeat\r\ndata: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'Chào Việt Nam'})}\r\n\r\ndata: {"type":"response.completed"}\n\n';
      final chunks = utf8.encode(text).map((byte) => <int>[byte]);
      final events = await ChatGptClient.decodeEvents(
        Stream.fromIterable(chunks),
      ).toList();
      expect(events.length, 2);
      expect(events.first['delta'], 'Chào Việt Nam');
      expect(events.last['type'], 'response.completed');
    },
  );
  test(
    'model stays with conversation when the global preference changes',
    () async {
      final api = FakeChatGpt()..model = 'first';
      final chat = DocumentChat(client: api);
      await chat.initialize();
      api.model = 'second';
      api.changed();
      expect(chat.selectedModel, 'first');
      api.identity = 'two';
      api.changed();
      expect(chat.messages, isEmpty);
      expect(chat.selectedModel, 'second');
      chat.dispose();
      await api.stream.close();
      api.dispose();
    },
  );
  test('cancelled partial response is excluded from later history', () async {
    final api = FakeChatGpt()..model = 'first';
    final chat = DocumentChat(client: api);
    await chat.initialize();
    chat.input.text = 'A';
    final task = chat.send();
    await Future<void>.delayed(Duration.zero);
    api.stream.add('Đang');
    await Future<void>.delayed(Duration.zero);
    chat.stop();
    expect(chat.busy, false);
    expect(chat.messages[0].complete, false);
    await api.stream.close();
    await task;
    expect(chat.messages.last.complete, false);
    chat.dispose();
    api.dispose();
  });
  testWidgets(
    'sheet dismissal retains editor, draft, conversation and pending reply',
    (tester) async {
      final api = FakeChatGpt()..model = 'first';
      api.models = [const ChatGptModel('first', 'Model của tôi')];
      final chat = DocumentChat(client: api);
      await chat.initialize();
      chat.input.text = 'Bản nháp chưa gửi';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDocumentAi(context, chat, 'Báo cáo.docx'),
                child: const Text('Mở AI'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở AI'));
      await tester.pumpAndSettle();
      expect(find.text('Bản nháp chưa gửi'), findsOneWidget);
      await tester.tap(find.byKey(const Key('collapse-ai')));
      await tester.pumpAndSettle();
      expect(chat.input.text, 'Bản nháp chưa gửi');
      chat.input.text = 'Tóm tắt';
      final task = chat.send();
      await tester.pump();
      api.stream.add('Kết quả');
      await tester.pump();
      await tester.tap(find.text('Mở AI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Kết quả'), findsOneWidget);
      await tester.tap(find.byKey(const Key('collapse-ai')));
      await tester.pumpAndSettle();
      expect(chat.busy, true);
      await api.stream.close();
      await task;
      expect(chat.messages.last.complete, true);
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      api.dispose();
    },
  );
}
