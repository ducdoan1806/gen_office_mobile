import '../features/ai/data/mock_factory_ai_service.dart';
import '../features/ai/domain/factory_ai_service.dart';
import '../features/documents/data/memory_document_repository.dart';
import '../features/documents/data/local_document_repository.dart';
import '../features/documents/domain/document_repository.dart';

class AppDependencies {
  const AppDependencies({required this.documents, required this.ai});
  factory AppDependencies.local() => AppDependencies(
    documents: LocalDocumentRepository(),
    ai: MockFactoryAiService(),
  );
  factory AppDependencies.mock() => AppDependencies(
    documents: MemoryDocumentRepository(),
    ai: MockFactoryAiService(),
  );
  final DocumentRepository documents;
  final FactoryAiService ai;
}
