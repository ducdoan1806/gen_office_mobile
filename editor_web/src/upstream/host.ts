document.documentElement.dataset.host = 'mobile';
import { defaultAiSettings } from '../../vendor/ai-provider/src/providers';
export class HostEvents {
    private listeners = new Map<string, Set<(...args: any[]) => any>>();
    on(name: string, fn: (...args: any[]) => any) { const set = this.listeners.get(name) ?? new Set(); set.add(fn); this.listeners.set(name, set); return () => set.delete(fn); }
    emit(name: string, ...args: any[]) { for (const fn of this.listeners.get(name) ?? [])
        fn(...args); }
}
export function desktopApi(methods: Record<string, any>, events: HostEvents) {
    const defaults: Record<string, any> = { setAutoSavePref: async (value: any) => value, clipboardProbe: async () => false, privateFontFaces: async () => [], getRecentFiles: async () => [], aiGskStatus: async () => ({ loggedIn: false }), getLanguage: async () => 'vi', getTheme: async () => 'light', getDocumentTheme: async () => 'light', getAutoSaveDefault: async () => false, getAiPanelPrefs: async () => ({ side: 'left', fontSize: 'default', customFontSize: 14, spellcheck: false, openInNewDocs: false, showAiSidebar: false }), getAiSettings: async () => ({ ...defaultAiSettings(), gskToolsEnabled: false }), getUserDisplayName: async () => 'GenOffice', getUsername: async () => 'GenOffice', getRecent: async () => [], listFonts: async () => ['Arial', 'Calibri', 'Carlito', 'Times New Roman'], getPrivateFonts: async () => [], listPrivateFonts: async () => [], getSystemFonts: async () => [], getFontMetrics: async () => null, getAiModelCatalog: async () => [], getAiSnapshots: async () => [], listPrinters: async () => [], consumeHeadlessExport: async () => null, consumeNewBlankWorkbook: async () => false, hasQueuedWorkbook: async () => false, notifyPendingEdits: () => { }, setDirty: () => { }, openExternal: async () => { }, getAiPanelVisible: async () => false, ...methods };
    return new Proxy(defaults, { get(target, key: string) { if (key in target)
            return target[key]; if (key.startsWith('on'))
            return (fn: any) => events.on(key, fn); if (/^(report|notify|signal|reply|headlessExportDone)/.test(key))
            return () => { }; return async () => { console.warn(`Unsupported Android host method: ${key}`); throw Error('Chức năng này chưa được hỗ trợ trên Android.'); }; } });
}
export function send(value: unknown) { (window as any).GenOfficeHost?.postMessage(JSON.stringify(value)); }
export const base = new URL('./', location.href);
export async function readDocument(url: string) { const locationUrl = new URL(url, base); if (locationUrl.origin !== base.origin || !locationUrl.pathname.startsWith(base.pathname + 'documents/'))
    throw Error('Địa chỉ tài liệu không hợp lệ.'); const response = await fetch(locationUrl); if (!response.ok)
    throw Error('Không đọc được tài liệu.'); return new Uint8Array(await response.arrayBuffer()); }
export async function writeDocument(bytes: Uint8Array, name: string, options: {
    copy?: boolean;
    recoveryId?: string;
} = {}) { const url = new URL(options.recoveryId ? 'recovery' : 'exports', base); url.searchParams.set(options.recoveryId ? 'documentId' : 'name', options.recoveryId ?? name); if (options.copy)
    url.searchParams.set('mode', 'copy'); const response = await fetch(url, { method: 'POST', body: bytes as BodyInit }); const result = await response.json(); if (!response.ok || !result.ok)
    throw Error(result.error || 'Không lưu được tài liệu.'); if (!options.recoveryId)
    send({ type: 'saved', name: result.name, path: result.path }); return result; }
export function installCommands(open: (args: any) => Promise<any>) {
    const win = window as any;
    let ready = false, busy = false;
    const queued: {
        command: any;
        resolve: (v: any) => void;
        reject: (e: any) => void;
    }[] = [];
    const invoke = (command: any) => new Promise((resolve, reject) => { queued.push({ command, resolve, reject }); drain(); });
    async function drain() { if (busy || !ready || !win.genOfficeRenderer)
        return; busy = true; try {
        while (queued.length && win.genOfficeRenderer) {
            const next = queued.shift()!;
            try {
                let command = next.command;
                if (command.method === 'open') command = {...command,args:await open(command.args)};
                next.resolve(await win.genOfficeRenderer(command));
            }
            catch (e) {
                next.reject(e);
            }
        }
    }
    finally {
        busy = false;
    } }
    window.addEventListener('genoffice:ready', () => { ready = true; send({ type: 'ready', protocol: 1 }); void drain(); });
    win.genOfficeMobile = { async receive(command: any) { try {
            const value = await invoke(command);
            send({ type: 'reply', id: command.id, ok: true, value });
        }
        catch (e) {
            send({ type: 'reply', id: command.id, ok: false, error: String(e) });
        } } };
    window.addEventListener('error', event => send({ type: 'error', error: event.message }));
    window.addEventListener('unhandledrejection', event => send({ type: 'error', error: String(event.reason) }));
}
