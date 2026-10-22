import { workbookFileSchema } from '../../vendor/sheets/src/shared/desktop-api';
import { Buffer } from 'buffer';
import JSZip from 'jszip';
import { XMLParser } from 'fast-xml-parser';
import { readBasicWorkbook, createBufferEntrySource, planCellEditsToXlsx, assembleWithJsZip } from '../../vendor/xlsx-gateway/src/gateway/xlsx-gateway';
import { assertZipInflatesWithinLimits } from '@genoffice/zip-gate';
import { prepareWorkbookSave } from './sheets-save';
import { address } from './cell-address';
const list = (v: any): any[] => v == null ? [] : Array.isArray(v) ? v : [v];
const parser = new XMLParser({ ignoreAttributes: false, removeNSPrefix: true });
const attr = (v: any, k: string, d?: any) => v?.['@_' + k] ?? d;
const present = (v: any) => v !== undefined && attr(v, 'val', '1') !== '0';
const color = (v: any) => attr(v, 'rgb') ? '#' + String(attr(v, 'rgb')).slice(-6) : undefined;
const area = (ref: string) => { const [a, b] = ref.split(':').map(address), z = b ?? a; return { startRow: a.row - 1, endRow: z.row - 1, startColumn: a.col - 1, endColumn: z.col - 1 }; };
const part = (base: string, target: string) => { const parts = target.startsWith('/') ? [] : base.split('/').slice(0, -1); for (const p of target.split('/'))
    if (p === '..')
        parts.pop();
    else if (p && p !== '.')
        parts.push(p); return parts.join('/'); };
export async function readXlsxSession(data: Uint8Array, name: string) {
    if (data.length > 32 * 1024 * 1024)
        throw Error('Tài liệu vượt 32 MB.');
    await assertZipInflatesWithinLimits(data, { maxParts: 10000, maxPartBytes: 64 * 1024 * 1024, maxTotalBytes: 256 * 1024 * 1024 });
    const zip = await JSZip.loadAsync(data), imported = await readBasicWorkbook(Buffer.from(data));
    const xml = async (p: string) => { const file = zip.file(p); if (!file)
        return {}; const text = await file.async('string'); if (/<!DOCTYPE|<!ENTITY/i.test(text))
        throw Error('XML không hợp lệ.'); return parser.parse(text); };
    const roots = list((await xml('_rels/.rels')).Relationships?.Relationship);
    const bookPath = part('', attr(roots.find(r => String(attr(r, 'Type')).endsWith('/officeDocument')), 'Target', 'xl/workbook.xml'));
    const book = (await xml(bookPath)).workbook;
    const relPath = bookPath.replace(/([^/]+)$/, '_rels/$1.rels');
    const rels = list((await xml(relPath)).Relationships?.Relationship);
    const resolve = (id: string) => part(bookPath, attr(rels.find(r => attr(r, 'Id') === id), 'Target'));
    const styleRel = rels.find(r => String(attr(r, 'Type')).endsWith('/styles'));
    const style = styleRel ? (await xml(part(bookPath, attr(styleRel, 'Target')))).styleSheet : {};
    const fonts = list(style?.fonts?.font), fills = list(style?.fills?.fill), customFormats = list(style?.numFmts?.numFmt);
    const builtin: Record<number, string> = { 0: 'General', 1: '0', 2: '0.00', 3: '#,##0', 4: '#,##0.00', 9: '0%', 10: '0.00%', 14: 'm/d/yyyy', 22: 'm/d/yyyy h:mm', 49: '@' };
    const styles = list(style?.cellXfs?.xf).map(x => { const f = fonts[Number(attr(x, 'fontId', 0))], fill = fills[Number(attr(x, 'fillId', 0))]; return { bold: present(f?.b), italic: present(f?.i), underline: present(f?.u), strikethrough: present(f?.strike), wrapText: attr(x.alignment, 'wrapText') === '1', diagonalUp: false, diagonalDown: false, fontFamily: attr(f?.name, 'val'), fontSize: Number(attr(f?.sz, 'val', 11)), fontColor: color(f?.color), fillColor: color(fill?.patternFill?.fgColor), horizontalAlignment: attr(x.alignment, 'horizontal'), verticalAlignment: attr(x.alignment, 'vertical'), numberFormat: attr(customFormats.find(n => Number(attr(n, 'numFmtId')) === Number(attr(x, 'numFmtId'))), 'formatCode', builtin[Number(attr(x, 'numFmtId', 0))] ?? 'General') }; });
    const sheetNodes = list(book.sheets?.sheet);
    const ranges = new Map();
    const metas = [];
    for (let i = 0; i < imported.snapshot.sheets.length; i++) {
        const sheet = imported.snapshot.sheets[i], node = sheetNodes.find(n => attr(n, 'name') === sheet.name), path = resolve(attr(node, 'id')), raw = (await xml(path)).worksheet;
        const rawRows = list(raw.sheetData?.row);
        const records = new Map<string, any>();
        let rows = 1, cols = 1;
        for (const [ref, cell] of Object.entries(sheet.cells)) {
            const pos = address(ref);
            rows = Math.max(rows, pos.row);
            cols = Math.max(cols, pos.col);
            records.set(ref, { row: pos.row - 1, column: pos.col - 1, value: cell.value, ...(cell.formula ? { formula: cell.formula } : {}) });
        }
        for (const row of rawRows)
            for (const cell of list(row.c)) {
                const ref = attr(cell, 'r');
                if (!ref)
                    continue;
                const pos = address(ref);
                rows = Math.max(rows, pos.row);
                cols = Math.max(cols, pos.col);
                const item = records.get(ref) ?? { row: pos.row - 1, column: pos.col - 1, value: null };
                item.styleIndex = Number(attr(cell, 's', 0));
                records.set(ref, item);
            }
        const view = list(raw.sheetViews?.sheetView)[0], pane = view?.pane;
        const merges = list(raw.mergeCells?.mergeCell).map(m => area(attr(m, 'ref')));
        const metadata = { id: sheet.id, name: sheet.name, rowCount: rows, columnCount: cols, storedCellCount: records.size, valueCellCount: Object.keys(sheet.cells).length, valueRowCount: rows, valueColumnCount: cols, columnWidths: list(raw.cols?.col).map(c => ({ startColumn: Number(attr(c, 'min', 1)) - 1, endColumn: Number(attr(c, 'max', 1)) - 1, width: Number(attr(c, 'width', 8.43)), hidden: attr(c, 'hidden') === '1' })), defaultRowHeight: Number(attr(raw.sheetFormatPr, 'defaultRowHeight', 15)), defaultColumnWidth: Number(attr(raw.sheetFormatPr, 'defaultColWidth', 8.43)), freeze: pane && String(attr(pane, 'state', '')).startsWith('frozen') ? { frozenRows: Number(attr(pane, 'ySplit', 0)), frozenColumns: Number(attr(pane, 'xSplit', 0)) } : null, hidden: attr(node, 'state', 'visible') !== 'visible', tabColor: color(raw.sheetPr?.tabColor) ?? null, showGridLines: attr(view, 'showGridLines', '1') !== '0', tables: [], comments: [], pivotTables: [], pivotRanges: [] };
        metas.push(metadata);
        ranges.set(sheet.id, { cells: [...records.values()], rows: rawRows.map(r => ({ row: Number(attr(r, 'r', 1)) - 1, ...(attr(r, 'ht') ? { height: Number(attr(r, 'ht')) } : {}), hidden: attr(r, 'hidden') === '1', ...(attr(r, 'customHeight') === '1' ? { customHeight: true } : {}) })), merges, hyperlinks: [], conditionalRules: [], autoFilter: raw.autoFilter ? area(attr(raw.autoFilter, 'ref')) : null, autoFilterColumns: [], dataValidations: [], sheetProtection: raw.sheetProtection ? { protected: true, hasPassword: !!attr(raw.sheetProtection, 'password') } : null, rowBreaks: [], colBreaks: [], pageSetup: null, protectedRanges: [], indexedThroughRow: rows - 1, indexingComplete: true });
    }
    const file = { sessionId: crypto.randomUUID(), name, path: 'mobile://' + name, sha256: (await import('../platform/node/crypto')).createHash('sha256').update(data).digest('hex'), fileBytes: data.length, entryCount: Object.keys(zip.files).length, sheets: metas, activeTab: 0, styles, dxfStyles: [], visuals: [], definedNames: [], readOnly: false };
    const session = { file: workbookFileSchema.parse(file), bytes: data, ranges, sheetNames: new Map(metas.map(s => [s.id, s.name])) };
    return session;
}
export async function serializeXlsxSession(s: any, request: any) {
    const p = prepareWorkbookSave(s, request);
    const plan = await planCellEditsToXlsx(await createBufferEntrySource(Buffer.from(s.bytes)), p.edits, p.structuralOps, p.chartEdits, p.sheetPlan, p.filterStates, p.hyperlinkEdits, p.cfStates, p.dvStates, p.sheetProtections, p.definedNamesState, p.visualAdditions, p.pageSetupStates, p.noteStates, p.tableAdditions, p.pivotAdditions, p.pivotCacheRefreshPaths, p.pivotRefreshUpdates, p.visualEdits, p.sparklineAdditions, p.formulaValues, p.themeState, p.workbookProtectionState, p.protectedRangeStates, p.bulkConstantFills, p.tabColorStates, p.tableEdits, p.cellImageAdditions);
    const changed = plan.touchedEntries.length || plan.addedEntries.length || plan.removedEntries.length;
    const data = changed ? new Uint8Array((await assembleWithJsZip(Buffer.from(s.bytes), plan)).buffer) : s.bytes;
    return { bytes: data, touchedEntries: plan.touchedEntries };
}
