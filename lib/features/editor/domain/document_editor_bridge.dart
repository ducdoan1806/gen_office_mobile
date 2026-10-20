import 'editor_document.dart';

abstract interface class DocumentEditorBridge {
  Future<void> open(EditorDocument document);
  Future<EditorSaveResult> save();
  Future<void> undo();
  Future<void> redo();
  Future<bool> hasUnsavedChanges();
  Future<void> close();
}
