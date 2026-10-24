import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'OAuth rejects forged state and handles valid denied callback without saving tokens',
    () async {
      const channel = MethodChannel('chatgpt-oauth-test');
      final writes = <String>[];
      final http = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        LoopbackHttpOverrides(),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'read') return null;
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
              final accepted = await denied.close();
              expect(accepted.statusCode, 200);
              await accepted.drain<void>();
              return null;
            }
            throw StateError('Unexpected platform method');
          });
      final client = ChatGptClient(platform: channel);
      try {
        await expectLater(client.connect(), throwsA(isA<ChatGptException>()));
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
      await tester.pumpAndSettle();
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
