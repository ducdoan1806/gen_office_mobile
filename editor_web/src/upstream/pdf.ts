import { Buffer } from 'buffer';
import { desktopApi, HostEvents, readDocument } from './host';
(globalThis as any).Buffer = Buffer;
(window as any).genOfficePdfReadOnly = true;
const api = desktopApi({ consumePending: async () => { const file = new URLSearchParams(location.search).get('file'); if (!file)
        throw Error('Chưa chọn PDF.'); return new URL(file, location.href).href; }, readFile: async (path: string) => { const bytes = await readDocument(path); if (bytes.length > 20 * 1024 * 1024)
        throw Error('PDF vượt giới hạn 20 MB.'); return bytes.buffer; }, listStaticFormFills: async () => [], listAnnotations: async () => [], listNotes: async () => [], listSignatures: async () => [], listDigitalSignatures: async () => [], listEditFonts: async () => [], getRecovery: async () => null, isUntitled: async () => false, canDrawText: async () => false, setDirty: () => { } }, new HostEvents());
(window as any).pdfApi = api;
try {
    await import('../../vendor/pdf/src/renderer/main');
}
catch (error) {
    document.getElementById('root')!.textContent = String(error);
    (window as any).GenOfficePdf?.postMessage(JSON.stringify({ type: 'error', value: String(error) }));
}
