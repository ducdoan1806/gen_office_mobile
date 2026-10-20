import type { DocumentStorage, DocumentFile } from './document-storage';
export class BrowserDocumentStorage implements DocumentStorage {
  async read(file: File): Promise<DocumentFile> {
    if (!/\.docx$/i.test(file.name)) throw new Error('Chỉ hỗ trợ file .docx.');
    if (file.size > 20 * 1024 * 1024) throw new Error('Bản thử nghiệm giới hạn file 20 MB.');
    return {name: file.name, bytes: new Uint8Array(await file.arrayBuffer())};
  }
  async write(document: DocumentFile): Promise<void> {
    const url = URL.createObjectURL(new Blob([new Uint8Array(document.bytes)], {
      type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    }));
    const link = window.document.createElement('a');
    link.href = url;
    link.download = document.name.replace(/\.docx$/i, '') + '-edited.docx';
    window.document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30_000);
  }
}
