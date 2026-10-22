import { assertZipInflatesWithinLimits } from '@genoffice/zip-gate';
import { Buffer } from 'buffer';
import { readBasicWorkbook, applyCellEditsToXlsx, type CellEdit } from '../../vendor/xlsx-gateway/src/gateway/xlsx-gateway';
import { openPptx, savePptx, type OpenedPptx } from '@genoffice/pptx-engine';
import { runTxn } from '@genoffice/pptx-ops';
import { address, columnName } from './formula';
export class OfficePackage {
    private constructor(readonly kind: 'xlsx' | 'pptx', private original: Uint8Array) { }
    sheets: {
        id: string;
        name: string;
        cells: Record<string, any>;
    }[] = [];
    slides: string[] = [];
    deck?: OpenedPptx;
    private edits = new Map<string, CellEdit>();
    private history: any[] = [];
    private cursor = 0;
    private savedState = '';
    private originalState = '';
    static async open(bytes: Uint8Array, kind: 'xlsx' | 'pptx') {
        if (bytes.length > 32 * 1024 * 1024)
            throw Error('File vượt 32 MB.');
        await assertZipInflatesWithinLimits(bytes, { maxParts: 10000, maxPartBytes: 64 * 1024 * 1024, maxTotalBytes: 256 * 1024 * 1024 });
        const p = new OfficePackage(kind, bytes);
        if (kind === 'xlsx') {
            const imported = await readBasicWorkbook(Buffer.from(bytes));
            p.sheets = structuredClone(imported.snapshot.sheets) as any;
        }
        else {
            p.deck = await openPptx(bytes);
            p.slides = p.deck.deck.slides.map(s => s.path);
        }
        p.history = [p.snapshot()];
        p.savedState = p.fingerprint();
        p.originalState = p.savedState;
        return p;
    }
    private snapshot() { return this.kind === 'xlsx' ? { sheets: structuredClone(this.sheets), edits: new Map(this.edits) } : { slides: structuredClone(this.deck!.deck.slides), entries: new Map(this.deck!.archive.entries), size: { ...this.deck!.deck.size } }; }
    private restore(s: any) { if (this.kind === 'xlsx') {
        this.sheets = structuredClone(s.sheets);
        this.edits = new Map(s.edits);
    }
    else {
        this.deck!.deck.slides = structuredClone(s.slides);
        this.deck!.deck.size = { ...s.size };
        this.deck!.archive.entries.clear();
        for (const [k, v] of s.entries)
            this.deck!.archive.entries.set(k, v);
    } }
    private fingerprint() { return this.kind === 'xlsx' ? JSON.stringify([...this.edits]) : JSON.stringify(this.deck!.deck.slides); }
    private commit() { this.history.splice(++this.cursor); this.history.push(this.snapshot()); if (this.history.length > 101) {
        this.history.shift();
        this.cursor--;
    } }
    get dirty() { return this.fingerprint() !== this.savedState; }
    get canUndo() { return this.cursor > 0; }
    get canRedo() { return this.cursor < this.history.length - 1; }
    undo() { if (this.canUndo)
        this.restore(this.history[--this.cursor]); }
    redo() { if (this.canRedo)
        this.restore(this.history[++this.cursor]); }
    markSaved(bytes: Uint8Array) { this.savedState = this.fingerprint(); }
    input(index: number, ref: string) { const c = this.sheets[index].cells[ref]; return c?.formula ? (c.formula.startsWith('=') ? c.formula : '=' + c.formula) : String(c?.value ?? ''); }
    value(index: number, ref: string) { return this.sheets[index].cells[ref]?.value ?? ''; }
    cellStyle() { return {}; }
    setCell(index: number, ref: string, value: string) { const pos = address(ref); ref = columnName(pos.col) + pos.row; if (this.input(index, ref) === value)
        return; if (value.length > 32767)
        throw Error('Nội dung ô vượt 32.767 ký tự.'); const cell = value.startsWith('=') ? { value: null, formula: value } : { value: value === '' ? null : /^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(value) ? Number(value) : value === 'TRUE' ? true : value === 'FALSE' ? false : value }; this.sheets[index].cells[ref] = cell; this.edits.set(`${index}!${ref}`, { sheetName: this.sheets[index].name, row: pos.row - 1, column: pos.col - 1, writeValue: true, cell }); this.commit(); }
    private textFields(index: number) { const out: {
        el: any;
        paragraph: any;
        pi: number;
    }[] = []; for (const el of this.deck!.deck.slides[index].elements) {
        if ((el.type === 'text' || el.type === 'shape') && el.text)
            el.text.paragraphs.forEach((paragraph: any, pi: number) => out.push({ el, paragraph, pi }));
    } return out; }
    paragraphs(index: number) { return this.textFields(index); }
    paragraphText(index: number, paragraph: number) { return this.textFields(index)[paragraph].paragraph.runs.map((r: any) => r.text).join(''); }
    setParagraph(index: number, paragraph: number, value: string) { const fields = this.textFields(index), field = fields[paragraph]; if (!field)
        throw Error('Không tìm thấy đoạn văn.'); if (this.paragraphText(index, paragraph) === value)
        return; const previous = this.paragraphText(index, paragraph); let prefix = 0, suffix = 0; while (prefix < previous.length && prefix < value.length && previous[prefix] === value[prefix])
        prefix++; while (suffix < previous.length - prefix && suffix < value.length - prefix && previous[previous.length - 1 - suffix] === value[value.length - 1 - suffix])
        suffix++; let offset = 0, inserted = false; const editedRuns = field.paragraph.runs.map((r: any, ri: number) => { const start = offset, end = offset + r.text.length; offset = end; let text = r.text.slice(0, Math.max(0, Math.min(r.text.length, prefix - start))); if (!inserted && prefix <= end) {
        text += value.slice(prefix, value.length - suffix);
        inserted = true;
    } text += r.text.slice(Math.max(0, previous.length - suffix - start)); return { text, srcRun: ri }; }); if (!inserted)
        editedRuns.push({ text: value.slice(prefix, value.length - suffix), srcRun: Math.max(0, editedRuns.length - 1) }); const paragraphs = field.el.text.paragraphs.map((p: any, pi: number) => ({ srcPara: pi, runs: pi === field.pi ? editedRuns : p.runs.map((r: any, ri: number) => ({ text: r.text, srcRun: ri })) })); const result = runTxn(this.deck!, { ops: [{ op: 'setText', target: { slide: index, el: field.el.id }, paragraphs }] }); if (!result.applied)
        throw Error(result.failures?.map(f => f.error).join('\n') || 'Không sửa được slide.'); this.commit(); }
    applyOperation(op: any) { const result = runTxn(this.deck!, { ops: [op] }); if (!result.applied)
        throw Error(result.failures?.map(f => f.error).join('\n') || 'Không áp dụng được thay đổi.'); this.commit(); }
    async bytes() { if(this.fingerprint()===this.originalState)return this.original; if (this.kind === 'pptx')
        return savePptx(this.deck!); if (!this.edits.size)
        return this.original; return new Uint8Array((await applyCellEditsToXlsx(Buffer.from(this.original), [...this.edits.values()])).buffer); }
}
