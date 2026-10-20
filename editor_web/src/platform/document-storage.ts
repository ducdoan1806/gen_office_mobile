export interface DocumentFile { name: string; bytes: Uint8Array }
/** Host boundary. Flutter can provide a separate adapter in the WebView phase. */
export interface DocumentStorage {
  read(file: File): Promise<DocumentFile>;
  write(document: DocumentFile): Promise<void>;
}
