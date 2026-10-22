import { LocaleType, mergeLocales } from '@univerjs/core';
import { UniverSheetsCorePreset } from '@univerjs/preset-sheets-core';
import enUS from '@univerjs/preset-sheets-core/locales/en-US';
import '@univerjs/preset-sheets-core/lib/index.css';
import { createUniver } from '../../vendor/sheets/src/renderer/create-univer';
import type { OfficePackage } from './package';
import { address, columnName } from './formula';
let runtime: ReturnType<typeof createUniver> | undefined, model: OfficePackage | undefined;
export function renderWorkbook(container: HTMLElement, pack: OfficePackage, index: number) {
    disposeWorkbook();
    model = pack;
    container.id = 'univer-container';
    container.style.height = '65dvh';
    runtime = createUniver({ locale: LocaleType.EN_US, locales: { [LocaleType.EN_US]: mergeLocales(enUS) }, presets: [UniverSheetsCorePreset({ container, header: true, toolbar: false, contextMenu: false, formulaBar: true, footer: { sheetBar: false, statisticBar: false, menus: false, zoomSlider: false } })] });
    const sheets = Object.fromEntries(pack.sheets.map(s => { const cellData: Record<number, Record<number, any>> = {}; let maxRow = 100, maxCol = 26; for (const [ref, cell] of Object.entries(s.cells)) {
        const { row, col } = address(ref);
        maxRow = Math.max(maxRow, row + 50);
        maxCol = Math.max(maxCol, col + 10);
        (cellData[row - 1] ??= {})[col - 1] = cell.formula ? { f: cell.formula.startsWith('=') ? cell.formula : '=' + cell.formula, v: cell.value } : { v: cell.value };
    } return [s.id, { id: s.id, name: s.name, rowCount: maxRow, columnCount: maxCol, cellData }]; }));
    (window as any).genOfficeSheets = runtime.univerAPI;
    const book = runtime.univerAPI.createWorkbook({ id: 'mobile-workbook', name: 'GenOffice', sheetOrder: pack.sheets.map(s => s.id), sheets });
    book.setActiveSheet(pack.sheets[index].id);
}
export function flushWorkbook() { if (!runtime || !model)
    return; const snapshot = runtime.univerAPI.getActiveWorkbook()?.save(); if (!snapshot)
    return; for (let i = 0; i < model.sheets.length; i++) {
    const s = snapshot.sheets[model.sheets[i].id];
    if (!s)
        continue;
    const refs = new Set(Object.keys(model.sheets[i].cells));
    for (const [r, row] of Object.entries(s.cellData ?? {}))
        for (const c of Object.keys(row ?? {}))
            refs.add(columnName(Number(c) + 1) + (Number(r) + 1));
    for (const ref of refs) {
        const { row, col } = address(ref);
        const cell = s.cellData?.[row - 1]?.[col - 1];
        const value = cell?.f ? cell.f.startsWith('=') ? cell.f : '=' + cell.f : String(cell?.v ?? '');
        model.setCell(i, ref, value);
    }
} }
export function disposeWorkbook() { runtime?.univer.dispose(); runtime = undefined; model = undefined; }
export function workbookEditing() { return (runtime?.univerAPI.getActiveWorkbook() as any)?.isCellEditing?.() === true; }
export async function commitWorkbook() { const b = runtime?.univerAPI.getActiveWorkbook() as any; if (b?.isCellEditing?.() && !(await b.endEditingAsync(true)))
    throw Error('Chưa hoàn tất nhập ô.'); }
