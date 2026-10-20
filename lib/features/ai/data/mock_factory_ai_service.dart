import '../domain/factory_ai_service.dart';

class MockFactoryAiService implements FactoryAiService {
  final Set<String> _active = {};
  @override
  Stream<AiEvent> run({
    required String requestId,
    required String instruction,
    required DocumentContext context,
  }) async* {
    if (!_active.add(requestId)) throw StateError('Duplicate request ID');
    try {
      yield const AiEvent(AiEventType.status, 'Đang mô phỏng API nhà máy…');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!_active.contains(requestId)) return;
      yield AiEvent(
        AiEventType.text,
        'Phản hồi mẫu cho yêu cầu: "$instruction". API AI nội bộ chưa được kết nối. Không có thay đổi nào được áp dụng vào tài liệu.',
      );
      yield const AiEvent(AiEventType.completed, 'Hoàn tất');
    } finally {
      _active.remove(requestId);
    }
  }

  @override
  Future<void> cancel(String requestId) async => _active.remove(requestId);
}
