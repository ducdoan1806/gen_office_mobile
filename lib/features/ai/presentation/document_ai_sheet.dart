import 'dart:async';
import 'dart:io';
import '../data/ai_document_edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/chatgpt_client.dart';

enum AiRequestPhase { readingDocument, waiting, receiving }

class ChatMessage {
  ChatMessage(this.role, this.text, {this.complete = true});
  final String role;
  String text;
  bool complete;
  String? wireText;
  AiDocumentEdit? edit;
}

/// Owned by the editor, so dismissing the sheet doesn't cancel the request.
class DocumentChat extends ChangeNotifier {
  DocumentChat({ChatGptClient? client})
    : client = client ?? ChatGptClient.instance {
    this.client.addListener(_accountChanged);
  }
  final ChatGptClient client;
  final input = TextEditingController();
  final messages = <ChatMessage>[];
  String attachment = '';
  String? documentName;
  bool applying = false;
  Future<Map<String, dynamic>> Function()? readDocument;
  Future<void> Function(Map<String, Object?>)? applyDocument;
  Future<void> applyEdit(AiDocumentEdit edit) async {
    if (busy || applying || edit.applied || disposed) return;
    applying = true;
    error = null;
    notifyListeners();
    try {
      await applyDocument!(edit.payload);
      edit.applied = true;
    } catch (e) {
      error = 'Không áp dụng được: $e';
    } finally {
      applying = false;
      if (!disposed) notifyListeners();
    }
  }

  String? selectedModel;
  String? error, _subject;
  bool busy = false, loading = false, disposed = false;
  AiRequestPhase? phase;
  String? get progressLabel => switch (phase) {
    AiRequestPhase.readingDocument => 'Đã nhận yêu cầu · Đang đọc tài liệu…',
    AiRequestPhase.waiting => 'Đã nhận yêu cầu · Đang chờ ChatGPT…',
    AiRequestPhase.receiving => 'AI đang trả lời…',
    null => null,
  };
  HttpClient? _transport;
  int _generation = 0;
  void _accountChanged() {
    if (_subject != client.subject) {
      stop();
      messages.clear();
      input.clear();
      attachment = '';
      _subject = client.subject;
      selectedModel = null;
    }
    selectedModel ??= client.model;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      await client.initialize();
      _subject = client.subject;
      if (client.interruptedAuth) {
        error =
            'Android đã dừng phiên đăng nhập trước. Bấm Continue with ChatGPT để tiếp tục; trình duyệt có thể đã nhớ tài khoản của bạn.';
      }
      if (client.connected && client.models.isEmpty) await client.loadModels();
      selectedModel ??= client.model;
    } catch (_) {
      error =
          'Không tải được kết nối ChatGPT. Kiểm tra mạng hoặc kết nối lại tài khoản.';
    } finally {
      loading = false;
      if (!disposed) notifyListeners();
    }
  }

  Future<void> send() async {
    if (busy || applying || !client.connected || input.text.trim().isEmpty) {
      return;
    }
    final question = input.text.trim();
    if (question.length > 6000 || attachment.length > 20000) {
      error =
          'Câu hỏi tối đa 6.000 ký tự; nội dung đính kèm tối đa 20.000 ký tự.';
      notifyListeners();
      return;
    }
    final hasDocument = readDocument != null;
    busy = true;
    error = null;
    final generation = ++_generation;
    final transport = _transport = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25);
    final user = ChatMessage('user', question, complete: false);
    final answer = ChatMessage('assistant', '', complete: false);
    messages.addAll([user, answer]);
    input.clear();
    phase = hasDocument
        ? AiRequestPhase.readingDocument
        : AiRequestPhase.waiting;
    notifyListeners();
    try {
      final snapshot = hasDocument ? await readDocument!() : null;
      final context = snapshot == null
          ? null
          : <String, dynamic>{
              ...snapshot,
              'editable':
                  applyDocument != null && snapshot['editable'] != false,
              'name': documentName,
            };
      if (disposed || generation != _generation) return;
      final content = context != null
          ? AiDocumentEdit.prompt(question, context, attachment: attachment)
          : attachment.isEmpty
          ? question
          : '$question\n\nNội dung tham khảo do người dùng đính kèm:\n$attachment';
      final history = messages
          .where((m) => m.complete)
          .map(
            (m) => {
              'role': m.role,
              'content': context == null ? (m.wireText ?? m.text) : m.text,
            },
          )
          .toList();
      history.add({'role': 'user', 'content': content});
      if (history.fold<int>(0, (n, m) => n + m['content']!.length) > 120000) {
        throw const ChatGptException(
          'Cuộc trò chuyện quá dài. Hãy tạo cuộc trò chuyện mới.',
        );
      }
      user.text = context == null
          ? question
          : "$question\n\n${context['scope']} · ${(context['entries'] as List).length} mục";
      user.wireText = content;
      phase = AiRequestPhase.waiting;
      notifyListeners();
      var response = '';
      await for (final delta in client.reply(
        history,
        transport: transport,
        modelId: selectedModel,
      )) {
        if (disposed || generation != _generation) return;
        response += delta;
        if (response.length > 160000) {
          throw const ChatGptException(
            'Kết quả quá lớn. Hãy chia nhỏ yêu cầu.',
          );
        }
        phase = AiRequestPhase.receiving;
        if (!hasDocument) answer.text = response;
        notifyListeners();
      }
      if (generation == _generation) {
        if (context != null) {
          final edit = AiDocumentEdit.parse(response, context);
          if (context['editable'] != true && edit.changes.isNotEmpty) {
            throw const FormatException(
              'Tài liệu chỉ đọc; không thể áp dụng thay đổi.',
            );
          }
          if (edit.changes.isNotEmpty) answer.edit = edit;
          answer.wireText = response;
          answer.text = edit.summary;
        }
        answer.complete = true;
        user.complete = true;
      }
    } catch (e) {
      if (!disposed && generation == _generation) {
        if (hasDocument) {
          answer.text = 'Chưa xử lý xong yêu cầu với tài liệu.';
        }
        error = e is ChatGptException
            ? e.message
            : hasDocument
            ? 'Không xử lý được tài liệu: $e'
            : 'Kết nối ChatGPT bị gián đoạn. Kiểm tra mạng và thử lại.';
      }
    } finally {
      if (!answer.complete && generation == _generation) {
        user.complete = false;
        // Keep a failed question retryable without overwriting a newer draft.
        if (input.text.isEmpty) input.text = question;
        if (answer.text.isEmpty) {
          answer.text = 'Yêu cầu chưa hoàn tất. Vui lòng thử lại.';
        }
      }
      transport.close(force: true);
      if (generation == _generation) {
        _transport = null;
        busy = false;
        phase = null;
      }
      if (!disposed) notifyListeners();
    }
  }

  void stop() {
    _generation++;
    _transport?.close(force: true);
    _transport = null;
    busy = false;
    phase = null;
    if (messages.isNotEmpty &&
        !messages.last.complete &&
        messages.last.text.isEmpty) {
      messages.last.text = 'Đã dừng yêu cầu.';
    }
    // An unanswered user turn must not be paired with the next request.
    if (messages.isNotEmpty &&
        !messages.last.complete &&
        messages.length >= 2) {
      messages[messages.length - 2].complete = false;
    }
    if (!disposed) notifyListeners();
  }

  void clear() {
    stop();
    messages.clear();
    attachment = '';
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    stop();
    client.removeListener(_accountChanged);
    input.dispose();
    super.dispose();
  }
}

Future<void> showDocumentAi(
  BuildContext context,
  DocumentChat session,
  String name,
) async {
  session.documentName = name;
  unawaited(session.initialize());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 230),
      reverseDuration: Duration(milliseconds: 200),
    ),
    builder: (_) => DocumentAiSheet(session: session, documentName: name),
  );
}

class DocumentAiSheet extends StatefulWidget {
  const DocumentAiSheet({
    super.key,
    required this.session,
    required this.documentName,
  });
  final DocumentChat session;
  final String documentName;
  @override
  State<DocumentAiSheet> createState() => _DocumentAiSheetState();
}

class _DocumentAiSheetState extends State<DocumentAiSheet> {
  final _scroll = ScrollController();
  DocumentChat get s => widget.session;
  @override
  void initState() {
    super.initState();
    _scrollDown();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> _connect() async {
    s.error = null;
    try {
      await s.client.connect();
    } catch (e) {
      s.error = e is ChatGptException
          ? e.message
          : 'Không kết nối được ChatGPT. Kiểm tra mạng, trình duyệt và quyền tài khoản.';
    }
    if (mounted) setState(() {});
  }

  Future<void> _attachment() async {
    final text = TextEditingController(text: s.attachment);
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Nội dung gửi cùng câu hỏi'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: text,
            minLines: 4,
            maxLines: 8,
            maxLength: 20000,
            decoration: const InputDecoration(
              hintText: 'Dán đoạn văn, vùng ô hoặc nội dung slide cần hỏi.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, text.text.trim()),
            child: const Text('Đính kèm'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value != null && mounted) setState(() => s.attachment = value);
  }

  Future<void> _preview(AiDocumentEdit edit) async {
    FocusScope.of(context).unfocus();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AnimatedBuilder(
        animation: s,
        builder: (context, _) => AlertDialog(
          title: const Text('Xem trước thay đổi AI'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(edit.summary),
                  const SizedBox(height: 12),
                  for (final c in edit.changes) ...[
                    Text(
                      c['label']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('Trước', style: TextStyle(color: Colors.red)),
                    SelectableText(
                      c['before']!.isEmpty ? '(trống)' : c['before']!,
                    ),
                    const Text('Sau', style: TextStyle(color: Colors.green)),
                    SelectableText(c['after']!.isEmpty ? '(xóa)' : c['after']!),
                    const Divider(),
                  ],
                  const Text(
                    'Áp dụng vào editor; dùng Hoàn tác để hủy. Bấm Lưu trong tài liệu để cập nhật file gốc.',
                  ),
                  if (s.error != null)
                    Text(
                      s.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: s.applying ? null : () => Navigator.pop(dialog),
              child: const Text('Đóng'),
            ),
            if (!edit.applied)
              FilledButton(
                onPressed: s.applying || s.busy
                    ? null
                    : () async {
                        await s.applyEdit(edit);
                        if (edit.applied && dialog.mounted) {
                          Navigator.pop(dialog);
                        }
                      },
                child: Text(s.applying ? 'Đang áp dụng…' : 'Áp dụng'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _models() async {
    if (s.busy) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Model của tài khoản ChatGPT')),
            for (final model in s.client.models)
              ListTile(
                title: Text(model.name),
                trailing: s.selectedModel == model.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, model.id),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      try {
        await s.client.chooseModel(chosen);
        s.selectedModel = chosen;
        if (mounted) setState(() {});
      } catch (_) {
        if (mounted) setState(() => s.error = 'Không lưu được lựa chọn model.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([s, s.client]),
    builder: (context, _) {
      final client = s.client;
      final colors = Theme.of(context).colorScheme;
      final compact =
          MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom <
          500;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      MediaQuery.paddingOf(context).top -
                      40)
                  .clamp(0.0, MediaQuery.sizeOf(context).height * .92),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Trợ lý AI',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cuộc trò chuyện mới',
                        onPressed: s.busy ? null : () => setState(s.clear),
                        icon: const Icon(Icons.add_comment_outlined),
                      ),
                      IconButton(
                        key: const Key('collapse-ai'),
                        tooltip: 'Thu gọn',
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                ),
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      widget.documentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      s.attachment.isEmpty
                          ? (s.readDocument != null
                                ? 'AI đang làm việc với tài liệu này'
                                : 'Chưa đính kèm nội dung tài liệu')
                          : 'Đã đính kèm ${s.attachment.length} ký tự',
                    ),
                    trailing: IconButton(
                      tooltip: 'Đính kèm nội dung',
                      onPressed: s.busy ? null : _attachment,
                      icon: const Icon(Icons.attach_file),
                    ),
                  ),
                if (s.loading) const LinearProgressIndicator(),
                if (client.connecting && s.messages.isNotEmpty)
                  ListTile(
                    dense: true,
                    title: const Text('Đang chờ đăng nhập trong trình duyệt…'),
                    trailing: TextButton(
                      onPressed: client.cancelConnect,
                      child: const Text('Hủy'),
                    ),
                  ),
                if (!compact && client.connected)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: s.busy || client.models.isEmpty
                                ? null
                                : _models,
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(
                              'ChatGPT · ${client.models.where((m) => m.id == s.selectedModel).firstOrNull?.name ?? 'Chọn model'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Tài khoản ChatGPT',
                          enabled: !s.busy && !client.connecting,
                          onSelected: (value) async {
                            if (value == 'refresh') {
                              await s.initialize();
                              if (client.models.isNotEmpty) {
                                await client.loadModels().catchError((_) {});
                              }
                            }
                            if (value == 'connect') await _connect();
                            if (value == 'disconnect') {
                              await client.disconnect().catchError((_) {
                                s.error = 'Không xóa được kết nối.';
                              });
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Text(client.email ?? 'Tài khoản cá nhân'),
                            ),
                            const PopupMenuItem(
                              value: 'refresh',
                              child: Text('Tải lại model'),
                            ),
                            const PopupMenuItem(
                              value: 'connect',
                              child: Text('Kết nối lại'),
                            ),
                            const PopupMenuItem(
                              value: 'disconnect',
                              child: Text('Ngắt kết nối'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: s.messages.isEmpty
                      ? SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 36,
                                  color: colors.primary,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Làm việc cùng ChatGPT',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  client.connected
                                      ? (s.readDocument != null
                                            ? 'Bạn đang làm việc với tài liệu này. Hỏi, tóm tắt hoặc yêu cầu chỉnh sửa trực tiếp; nội dung tài liệu/vùng chọn được gửi tới ChatGPT cá nhân khi bấm Gửi. Thay đổi sẽ có bản xem trước để bạn duyệt.'
                                            : 'Hỏi, dịch hoặc soạn lại nội dung. Nội dung bạn nhập và đính kèm được gửi đi.')
                                      : 'Kết nối tài khoản ChatGPT cá nhân bằng trình duyệt. Không cần nhập API key.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                if (!client.connected && !client.connecting)
                                  FilledButton(
                                    onPressed: s.loading ? null : _connect,
                                    child: const Text('Continue with ChatGPT'),
                                  ),
                                if (client.connecting) ...[
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Hoàn tất đăng nhập trong trình duyệt, rồi quay lại VPIC1 Office.',
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: client.cancelConnect,
                                    child: const Text('Hủy đăng nhập'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: s.messages.length,
                          itemBuilder: (context, index) {
                            final message = s.messages[index],
                                user = message.role == 'user';
                            return Align(
                              alignment: user
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(14),
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                ),
                                decoration: BoxDecoration(
                                  color: user
                                      ? colors.primaryContainer
                                      : colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!user)
                                      const Text(
                                        'ChatGPT',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (message.text.isNotEmpty)
                                      SelectableText(message.text),
                                    if (!user &&
                                        s.busy &&
                                        identical(message, s.messages.last))
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: message.text.isEmpty ? 8 : 12,
                                        ),
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Row(
                                            key: const Key('ai-waiting'),
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              const SizedBox(width: 10),
                                              Flexible(
                                                child: Text(
                                                  s.progressLabel ??
                                                      'Đang xử lý…',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (message.complete &&
                                        message.edit != null) ...[
                                      Text(
                                        '${message.edit!.changes.length} thay đổi đề xuất',
                                      ),
                                      if (message.edit!.changes.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () =>
                                              _preview(message.edit!),
                                          icon: Icon(
                                            message.edit!.applied
                                                ? Icons.check
                                                : Icons.preview_outlined,
                                          ),
                                          label: Text(
                                            message.edit!.applied
                                                ? 'Đã áp dụng · xem chi tiết'
                                                : 'Xem trước thay đổi',
                                          ),
                                        ),
                                    ],
                                    if (!user && message.text.isNotEmpty)
                                      IconButton(
                                        tooltip: 'Sao chép nội dung',
                                        onPressed: () => Clipboard.setData(
                                          ClipboardData(text: message.text),
                                        ),
                                        icon: const Icon(Icons.copy, size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (s.error != null && !compact)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 64),
                      child: SingleChildScrollView(
                        child: Text(
                          s.error!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  ),
                if (s.busy && !compact)
                  TextButton.icon(
                    onPressed: s.stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Dừng trả lời'),
                  ),
                Padding(
                  key: const ValueKey('ai-composer'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    key: const Key('ai-input'),
                    controller: s.input,
                    minLines: 1,
                    maxLines: compact
                        ? 1
                        : MediaQuery.viewInsetsOf(context).bottom > 0
                        ? 2
                        : 4,
                    maxLength: 6000,
                    enabled: client.connected && !s.loading && !s.applying,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: compact && s.error != null
                          ? s.error
                          : 'Bạn muốn làm gì với tài liệu?',
                      border: const OutlineInputBorder(),
                      suffixIcon: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (s.busy)
                              const SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            IconButton(
                              key: const Key('send-ai'),
                              tooltip: s.busy ? 'Dừng trả lời' : 'Gửi',
                              onPressed: s.busy
                                  ? s.stop
                                  : !client.connected || s.loading || s.applying
                                  ? null
                                  : () {
                                      unawaited(
                                        s.send().then((_) => _scrollDown()),
                                      );
                                      _scrollDown();
                                    },
                              icon: Icon(
                                s.busy ? Icons.stop : Icons.arrow_upward,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!compact)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'AI có thể sai. Kiểm tra trước khi dùng.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
