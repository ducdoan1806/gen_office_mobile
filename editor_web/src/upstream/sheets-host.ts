import { desktopApi, HostEvents, installCommands, readDocument, writeDocument, send } from './host';
import { readXlsxSession, serializeXlsxSession } from './xlsx-session';
import { workbookSaveEditsBeginSchema, workbookSaveEditsChunkSchema, saveEditsChunkArraySchema } from '../../vendor/sheets/src/shared/desktop-api';
const events = new HostEvents();
let current: any, bytes: Uint8Array, queuedFile: any, recoveryId: string | undefined, pendingEdits = 0;
const sessions = new Map<string, any>();
const transfers = new Map<string, {
    sessionId: string;
    total: number;
    seq: number;
    edits: any[];
}>();
async function load(data: Uint8Array, name: string) { const s = await readXlsxSession(data, name); sessions.set(s.file.sessionId, s); return s; }
const session = (id: string) => { const s = sessions.get(id); if (!s)
    throw Error('Phiên bảng tính đã đóng.'); return s; };
async function saveRequest(input: any, recovery = false) {
    const s = session(input.sessionId);
    let request = { ...input };
    if (request.editsTransferId) {
        const t = transfers.get(request.editsTransferId);
        if (!t || t.sessionId !== input.sessionId || t.edits.length !== t.total)
            throw Error('Dữ liệu lưu chưa truyền đủ.');
        request.edits = t.edits;
    }
    const { bytes: data, touchedEntries } = await serializeXlsxSession(s, request);
    if (request.editsTransferId)
        transfers.delete(request.editsTransferId);
    const result = await writeDocument(data, s.file.name, { copy: input.mode === 'save-as', recoveryId: recovery ? recoveryId : undefined });
    if (recovery)
        return { ok: true };
    current = await load(data, result.name);
    bytes = data;
    pendingEdits = 0;
    return { saved: true, canceled: false, file: current.file, touchedEntries };
}
(window as any).desktopApi = desktopApi({
    selectWorkbook: async () => { if (queuedFile) {
        const f = queuedFile;
        queuedFile = null;
        return f;
    } send({ type: 'pickDocument' }); return null; }, reopenWorkbook: async () => current.file, hasQueuedWorkbook: async () => !!queuedFile,
    readWorkbookRange: async (req: any) => { const r = session(req.sessionId).ranges.get(req.sheetId); if (!r)
        throw Error('Không tìm thấy sheet.'); return { ...r, cells: r.cells.filter((c: any) => c.row >= req.range.startRow && c.row <= req.range.endRow && c.column >= req.range.startColumn && c.column <= req.range.endColumn), rows: r.rows.filter((r: any) => r.row >= req.range.startRow && r.row <= req.range.endRow) }; },
    readWorkbookFormulas: async (req: any) => ({ cells: session(req.sessionId).ranges.get(req.sheetId).cells.filter((c: any) => c.formula), sharedGroups: [], indexingComplete: true, truncated: false }), readWorkbookRowOutline: async () => ({ rows: [], indexingComplete: true }), recalcWorkbook: async () => { throw Error('Công thức này cần bộ tính chưa hỗ trợ trên Android.'); },
    findWorkbookCells: async (req: any) => { const s = session(req.sessionId), matches = []; for (const [sheetId, r] of s.ranges)
        if (!req.sheetId || sheetId === req.sheetId)
            for (const c of r.cells) {
                const value = String(c.value ?? ''), query = req.query;
                const v = req.matchCase ? value : value.toLowerCase(), q = req.matchCase ? query : query.toLowerCase();
                if (req.matchEntireCell ? v === q : v.includes(q))
                    matches.push({ sheetId, ...c, valueText: value });
            } return { matches: matches.slice(0, req.limit), complete: matches.length <= req.limit, indexingComplete: true }; },
    notifyPendingEdits: (count: number) => pendingEdits = count, saveWorkbookEdits: (r: any) => saveRequest(r), writeWorkbookRecovery: (r: any) => recoveryId ? saveRequest(r, true) : Promise.resolve({ ok: false }), saveMobileUnchanged: async () => writeDocument(current.bytes, current.file.name), closeWorkbook: async (id: string) => { if (id !== current?.file.sessionId)
        sessions.delete(id); },
    beginSaveEditsTransfer: async (input: any) => { const r = workbookSaveEditsBeginSchema.parse(input); if (transfers.has(r.transferId))
        throw Error('Mã truyền dữ liệu đã tồn tại.'); transfers.set(r.transferId, { sessionId: r.sessionId, total: r.total, seq: 0, edits: [] }); }, sendSaveEditsChunk: async (input: any) => { const r = workbookSaveEditsChunkSchema.parse(input); const t = transfers.get(r.transferId); if (!t || t.sessionId !== r.sessionId || t.seq !== r.seq)
        throw Error('Thứ tự dữ liệu lưu không hợp lệ.'); const edits = saveEditsChunkArraySchema.parse(JSON.parse(r.editsJson)); if (!Array.isArray(edits) || t.edits.length + edits.length > t.total)
        throw Error('Dữ liệu lưu không hợp lệ.'); t.edits.push(...edits); t.seq++; }, abortSaveEditsTransfer: async (r: any) => transfers.delete(r.transferId),
}, events);
installCommands(async (args: any) => { bytes = await readDocument(args.url); current = await load(bytes, args.name); if (args.recovered)
    current.file.restoredFromRecovery = true; queuedFile = null; return { ...args, file: current.file }; });
(window as any).genOfficeSheetsRecovery = async (id: string, fn: () => Promise<any>) => { recoveryId = id; try {
    return await fn();
}
finally {
    recoveryId = undefined;
} };
