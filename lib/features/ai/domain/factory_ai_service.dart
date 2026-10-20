class DocumentContext {
  const DocumentContext({
    required this.documentId,
    required this.revision,
    required this.excerpts,
  });
  final String documentId;
  final int revision;
  final List<String> excerpts;
}

enum AiEventType { status, text, completed }

class AiEvent {
  const AiEvent(this.type, this.text);
  final AiEventType type;
  final String text;
}

/// AI is hosted by the factory. This interface never runs a model on-device.
/// Each run has a caller-generated ID, also used for cancellation.
abstract interface class FactoryAiService {
  Stream<AiEvent> run({
    required String requestId,
    required String instruction,
    required DocumentContext context,
  });
  Future<void> cancel(String requestId);
}
