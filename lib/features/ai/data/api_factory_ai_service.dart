import '../domain/factory_ai_service.dart';

/// Integration stub. Define auth, streaming protocol and operation schema
/// with the factory backend before implementing this adapter.
class ApiFactoryAiService implements FactoryAiService {
  ApiFactoryAiService({required this.baseUrl});
  final Uri baseUrl;
  @override
  Stream<AiEvent> run({
    required String requestId,
    required String instruction,
    required DocumentContext context,
  }) => Stream<AiEvent>.error(
    UnimplementedError('Factory AI API is not connected'),
  );
  @override
  Future<void> cancel(String requestId) => Future<void>.error(
    UnimplementedError('Factory AI cancellation API is not connected'),
  );
}
