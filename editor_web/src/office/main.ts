import { renderWorkbook, flushWorkbook, disposeWorkbook, commitWorkbook, workbookEditing } from './workbook';
import { renderPresentation, disposePresentation } from './presentation';
import { OfficePackage } from './package';
import { address, columnName } from './formula';
import './style.css';
const win = window as any;
const root = new URL('./', location.href);
const kind = new URLSearchParams(location.search).get('format') as 'xlsx' | 'pptx';
const el = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const send = (value: unknown) => win.GenOfficeHost?.postMessage(JSON.stringify(value));
const tell = (message: string, error = false) => { el('status').textContent = message; el('status').dataset.error = String(error); };
let pack: OfficePackage | undefined, name = '', selected = 0, composing = false, pending = false;
let slideEdits = new Map<number, string>();
function button(label: string, action: () => void | Promise<void>) { const b = document.createElement('button'); b.textContent = label; b.onclick = () => { try {
    Promise.resolve(action()).catch(e => tell(String(e), true));
}
catch (e) {
    tell(String(e), true);
} }; return b; }
function flush() {
    if (composing)
        throw Error('Đang nhập chữ. Hãy hoàn tất trước khi lưu.');
    if (!pack)
        return;
    if (kind === 'xlsx')
        flushWorkbook();
    if (kind === 'pptx') {
        for (const [paragraph, value] of slideEdits)
            pack.setParagraph(selected, paragraph, value);
        slideEdits.clear();
        pending = false;
    }
}
async function selectTab(index: number) { if (kind === 'xlsx')
    await commitWorkbook(); flush(); selected = index; render(); }
function tabs() { const tabs = el('tabs'); tabs.replaceChildren(); const names = kind === 'xlsx' ? pack!.sheets.map(s => s.name) : pack!.slides.map((_, i) => `Slide ${i + 1}`); names.forEach((label, index) => { const b = button(label, () => selectTab(index)); b.setAttribute('role', 'tab'); b.setAttribute('aria-selected', String(index === selected)); tabs.append(b); }); tabs.setAttribute('role', 'tablist'); }
function render() {
    disposePresentation();
    disposeWorkbook();
    tabs();
    el('tools').replaceChildren();
    el('content').replaceChildren();
    el('content').className = kind;
    if (kind === 'xlsx')
        sheet();
    else
        slides();
    el('tools').append(button('Lưu thành bản mới', () => { void saveCopy(); }));
    tell(pack!.dirty ? 'Có thay đổi chưa lưu.' : kind === 'xlsx' ? 'Chọn ô để sửa. Có thể nhập số, chữ hoặc công thức.' : 'Chọn slide và sửa nội dung bên dưới bản xem trước.');
}
function sheet() { const host = document.createElement('div'); el('content').append(host); renderWorkbook(host, pack!, selected); }
function slides() {
    const controls = el('tools');
    controls.append(button('Slide trước', () => selectTab(Math.max(0, selected - 1))), button('Slide sau', () => selectTab(Math.min(pack!.slides.length - 1, selected + 1))), button('Xem trước', () => { void preview(); }));
    const position = document.createElement('span');
    position.id = 'position';
    position.textContent = `${selected + 1} / ${pack!.slides.length}`;
    controls.append(position);
    const canvas = document.createElement('div');
    canvas.id = 'slide-canvas';
    el('content').append(canvas);
    renderPresentation(canvas, pack!, selected, p => { document.querySelector<HTMLInputElement>('[data-paragraph="' + p + '"]')?.focus(); });
    const fields = document.createElement('div');
    fields.className = 'paragraphs';
    pack!.paragraphs(selected).forEach((_, index) => { const label = document.createElement('label'); label.textContent = `Văn bản ${index + 1}`; const input = document.createElement('input'); input.value = pack!.paragraphText(selected, index); input.dataset.paragraph = String(index); input.oninput = () => { slideEdits.set(index, input.value); pending = true; tell('Có thay đổi chưa lưu.'); }; input.addEventListener('compositionstart', () => composing = true); input.addEventListener('compositionend', () => { composing = false; slideEdits.set(index, input.value); pending = true; }); label.append(input); fields.append(label); });
    if (!fields.children.length)
        fields.textContent = 'Slide này không có đoạn văn có thể sửa.';
    el('content').append(fields);
}
async function preview() { flush(); render(); }
async function exportBytes(recovery = false, documentId?: string, copy = false) { if (kind === 'xlsx')
    await commitWorkbook(); flush(); if (!pack)
    throw Error('Chưa mở tài liệu.'); if (recovery && !pack.dirty)
    return false; const bytes = await pack.bytes(); const url = new URL(recovery ? 'recovery' : 'exports', root); url.searchParams.set(recovery ? 'documentId' : 'name', recovery ? documentId! : name); if (copy)
    url.searchParams.set('mode', 'copy'); const response = await fetch(url, { method: 'POST', body: bytes as BodyInit }); const result = await response.json(); if (!response.ok || !result.ok)
    throw Error(result.error || 'Không lưu được tài liệu.'); if (!recovery) {
    name = result.name;
    pack.markSaved(bytes);
    tell('Đã lưu vào file gốc.');
    send({ type: 'saved', name: result.name, path: result.path });
} return true; }
async function saveCopy() { if (commandBusy)
    return; commandBusy = true; try {
    await exportBytes(false, undefined, true);
    recovered = false;
}
catch (error) {
    tell(String(error), true);
}
finally {
    commandBusy = false;
} }
let commandBusy = false;
win.genOfficeMobile = { async receive(command: any) {
        try {
            if (!command || typeof command.id !== 'string')
                throw Error('Lệnh không hợp lệ.');
            if (commandBusy)
                throw Error('Tài liệu đang xử lý. Vui lòng thử lại.');
            commandBusy = true;
            let value: any;
            switch (command.method) {
                case 'open': {
                    const args = command.args;
                    const url = new URL(String(args.url), root);
                    if (url.origin !== root.origin || !url.pathname.startsWith(root.pathname + 'documents/'))
                        throw Error('Địa chỉ tài liệu không hợp lệ.');
                    const response = await fetch(url);
                    if (!response.ok)
                        throw Error('Không đọc được tài liệu.');
                    pack = await OfficePackage.open(new Uint8Array(await response.arrayBuffer()), kind);
                    name = args.name;
                    selected = 0;
                    pending = false;
                    slideEdits.clear();
                    render();
                    if (args.recovered) { // A recovery is unsaved even if the ZIP is the initial editable state.
                        recovered = true;
                    }
                    else
                        recovered = false;
                    break;
                }
                case 'save':
                    value = await exportBytes();
                    recovered = false;
                    break;
                case 'snapshot':
                    value = (composing || workbookEditing()) ? false : await exportBytes(true, command.args.documentId);
                    break;
                case 'status':
                    if (kind === 'xlsx')
                        flushWorkbook();
                    value = { dirty: !!pack && (pack.dirty || pending || recovered || workbookEditing()), canUndo: pack?.canUndo, canRedo: pack?.canRedo };
                    break;
                case 'undo':
                    if (kind === 'xlsx')
                        await commitWorkbook();
                    flush();
                    pack?.undo();
                    render();
                    break;
                case 'redo':
                    if (kind === 'xlsx')
                        await commitWorkbook();
                    flush();
                    pack?.redo();
                    render();
                    break;
                case 'discard':
                    pending = false;
                    slideEdits.clear();
                    value = true;
                    break;
                default: throw Error('Lệnh chưa được hỗ trợ.');
            }
            send({ type: 'reply', id: command.id, ok: true, value });
        }
        catch (error) {
            tell(String(error), true);
            send({ type: 'reply', id: command.id, ok: false, error: String(error) });
        }
        finally {
            commandBusy = false;
        }
    } };
let recovered = false;
send({ type: 'ready', protocol: 1 });
