import { AiEditGuard } from './ai-edits';
import { openPptx, savePptx, listSlideLayouts, getSlideTransition, getSlideAdvanceTime, type OpenedPptx } from '@genoffice/pptx-engine';
import { getSlideNotes, setSlideNotes } from '../../vendor/pptx-engine/src/notes';
import { runTxn } from '@genoffice/pptx-ops';
import { buildRenderSlide, HeuristicMetrics } from '@genoffice/pptx-render';
import { Buffer } from 'buffer';
import { assertZipInflatesWithinLimits } from '@genoffice/zip-gate';
import { desktopApi, HostEvents, installCommands, readDocument, writeDocument, send } from './host';
const events = new HostEvents();
const aiGuard = new AiEditGuard();
let opened: OpenedPptx, name = 'presentation.pptx', original: Uint8Array, saved = '', metaDirty = false, fitWidth = 960, preview = false, recovered = false, unsaved = false;
const undoStack: any[] = [], redoStack: any[] = [];
let hasDocument = false, resolveInitial: ((v: any) => void) | undefined;
const initialDocument = new Promise<any>(resolve => resolveInitial = resolve);
const fingerprint = () => JSON.stringify(opened?.deck) + ':' + metaDirty;
const snapshot = () => ({ slides: structuredClone(opened.deck.slides), entries: new Map(opened.archive.entries), size: { ...opened.deck.size }, metaDirty });
function restore(s: any) { opened.deck.slides = structuredClone(s.slides); opened.deck.size = { ...s.size }; metaDirty = s.metaDirty; opened.archive.entries.clear(); for (const [k, v] of s.entries)
    opened.archive.entries.set(k, v); }
function notify() { events.emit('onHistoryChanged', { canUndo: undoStack.length > 0, canRedo: redoStack.length > 0 }); }
function render(index: number) { const slide = opened.deck.slides[index]; return buildRenderSlide(slide, opened.deck.size, { fitWidthPx: fitWidth, metrics: new HeuristicMetrics(), slideNo: index + 1, media(ref: string) { const bytes = opened.archive.readBytes(ref); if (!bytes)
        return; const ext = ref.split('.').pop()?.toLowerCase(); const mime = ({ png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', svg: 'image/svg+xml', webp: 'image/webp', bmp: 'image/bmp', tif: 'image/tiff' } as any)[ext!]; return mime ? `data:${mime};base64,${Buffer.from(bytes).toString('base64')}` : undefined; } }); }
const renderAll = () => opened.deck.slides.map((_, i) => render(i));
const openResult = () => ({ path: 'mobile://' + name, slides: renderAll(), size: opened.deck.size, defaultFont: 'Carlito' });
async function load(data: Uint8Array, filename: string) { aiGuard.invalidate(); if (data.length > 32 * 1024 * 1024)
    throw Error('Tài liệu vượt 32 MB.'); await assertZipInflatesWithinLimits(data, { maxParts: 10000, maxPartBytes: 64 * 1024 * 1024, maxTotalBytes: 256 * 1024 * 1024 }); opened = await openPptx(data); name = filename; unsaved = false; original = data; metaDirty = false; saved = fingerprint(); undoStack.length = redoStack.length = 0; notify(); return openResult(); }
function apply(ops: any[], isPreview = false) {
    const before = snapshot();
    const result = runTxn(opened, { ops });
    if (!result.applied)
        throw Error(result.failures?.map(f => f.error).join('\n') || 'Không áp dụng được thay đổi.');
    if (!preview) {
        undoStack.push(before);
        if (undoStack.length > 50)
            undoStack.shift();
        redoStack.length = 0;
    }
    preview = isPreview;
    notify();
    return result;
}
const target = (op: any, id = op.sourceId) => ({ slide: op.slideIndex, el: id });
const group = (op: any) => op.groupId ? { group: op.groupId } : {};
const single = (name: string, transform: (op: any) => any) => async (op: any) => { if (op.fitWidthPx)
    fitWidth = op.fitWidthPx; apply([{ op: name, target: target(op), ...group(op), ...transform(op) }], !!op.preview); return render(op.slideIndex); };
const multi = (name: string, key: string) => async (op: any) => { apply(op.sourceIds.map((id: string) => ({ op: name, target: target(op, id), ...group(op), [key]: Object.fromEntries(Object.entries(op).filter(([k]) => !['slideIndex', 'sourceIds', 'groupId'].includes(k))) }))); return render(op.slideIndex); };
async function save(copy = false, recoveryId?: string) { if (!hasDocument)
    throw Error('Đang mở tài liệu.'); copy = copy || unsaved; const data = fingerprint() === saved ? original : await savePptx(opened); const result = await writeDocument(data, name, { copy, recoveryId }); if (!recoveryId) {
    original = data;
    name = result.name;
    unsaved = false;
    metaDirty = false;
    recovered = false;
    saved = fingerprint();
} return { ok: true, path: 'mobile://' + name, slides: renderAll() }; }
(window as any).slidesApi = desktopApi({
    mobileAiContext: async (index: number) => {
        const entries: any[] = [];
        opened.deck.slides.forEach((slide,index) => slide.elements.forEach((el: any) => {
            if (el.type !== 'text' && el.type !== 'shape') return;
            el.text?.paragraphs.forEach((p: any, pi: number) => p.runs.forEach((r: any, ri: number) => {
                if (typeof r.text === 'string') entries.push({id: `${index}|${el.id}|${pi}|${ri}`, label: `Slide ${index+1} · ${el.id}`, text: r.text});
            }));
        }));
        return aiGuard.capture(fingerprint(), entries, `Văn bản bài trình chiếu · ${opened.deck.slides.length} slide (đang xem slide ${index+1})`);
    },
    mobileAiApply: async (args: any) => {
        const changes = aiGuard.validate(args, fingerprint());
        const groups = new Map<string, any>();
        for (const op of changes) {
            const [slideIndex, id, pi, ri] = op.id.split('|');
            const key = `${slideIndex}|${id}`;
            let group = groups.get(key);
            if (!group) {
                const element: any = opened.deck.slides[Number(slideIndex)]?.elements.find(e => e.id === id);
                if (!element?.text) throw Error('Không tìm thấy văn bản slide.');
                group = {op: 'setText', target: {slide: Number(slideIndex), el: id}, paragraphs: structuredClone(element.text.paragraphs)};
                groups.set(key,group);
            }
            group.paragraphs[Number(pi)].runs[Number(ri)].text = op.after;
        }
        apply([...groups.values()]); aiGuard.invalidate(); return renderAll();
    },
    getRecent: async () => [], consumePendingOpen: async (width: number) => { fitWidth = width; return initialDocument; }, openPptx: async () => { send({ type: 'pickDocument' }); return null; }, newBlankPptx: async () => null, newBlank: async () => { throw Error('Tạo tài liệu mới chưa hỗ trợ trên Android.'); }, getTransition: async (index: number) => opened?.deck.slides[index] ? getSlideTransition(opened.deck.slides[index]) : 'none', getShowTiming: async (index: number) => ({ advanceMs: opened?.deck.slides[index] ? getSlideAdvanceTime(opened.deck.slides[index]) : null, narrationIds: [] }), isDirty: async () => !!opened && (recovered || fingerprint() !== saved), getRenderSlides: async () => renderAll(),
    addElement: async (op: any) => { fitWidth = op.fitWidthPx ?? fitWidth; const k = opened.deck.size.cx / fitWidth; const r = apply([{ op: 'addElement', target: { slide: op.slideIndex }, kind: op.kind, offset: { x: op.xPx * k, y: op.yPx * k, cx: op.wPx * k, cy: op.hPx * k }, ...(op.text ? { paragraphs: op.text.split('\n').map((text: string) => ({ runs: [{ text }] })) } : {}), ...(op.paragraphs ? { paragraphs: op.paragraphs } : {}), ...(op.fillColor ? { fill: op.fillColor } : {}), ...(op.stroke ? { stroke: { color: op.stroke.color, widthEmu: Math.round(op.stroke.widthPt * 12700) } } : {}), ...(op.bodyPr ? { bodyPr: op.bodyPr } : {}) }]); return { slide: render(op.slideIndex), sourceId: r.records![0].created![0] }; },
    editPictureOpacity: single('setPictureOpacity', op => ({ opacity: op.opacity })), editPictureSrcRect: single('setPictureSrcRect', op => ({ srcRect: op.srcRect })), setTextAnchor: single('setTextAnchor', op => ({ anchor: op.anchor })), setEffects: single('setEffects', op => ({ effects: op.effects })), changeShape: single('setShapeGeometry', op => ({ prst: op.prst })),
    editText: single('setText', op => ({ paragraphs: op.paragraphs })), setElementFont: multi('setFont', 'font'), setElementParagraphFormat: multi('setParagraphFormat', 'format'),
    editTransform: single('setTransform', op => { const k = opened.deck.size.cx / op.fitWidthPx; return { box: { x: op.xPx * k, y: op.yPx * k, cx: op.wPx * k, cy: op.hPx * k }, rotDeg: op.rotationDeg }; }),
    cancelTransformPreview: async (op: any) => { if (preview && undoStack.length) {
        restore(undoStack.pop());
        preview = false;
        notify();
    } return render(op.slideIndex); },
    editFill: single('setFill', op => ({ fill: op.fill ?? op.color })), editStroke: single('setStroke', op => ({ stroke: op.stroke ? { ...op.stroke, widthEmu: Math.round(op.stroke.widthPt * 12700) } : null })), editTableCell: single('setTableCell', op => ({ row: op.row, col: op.col, paragraphs: op.paragraphs })),
    editBackground: async (op: any) => {
        if (op.kind === 'image') throw Error('Chọn ảnh nền chưa được hỗ trợ trên Android.');
        const indexes = op.slideIndex === -1 ? opened.deck.slides.map((_, i) => i) : [op.slideIndex];
        const common = op.kind === 'solid' ? {kind:'solid',color:op.color}
            : op.kind === 'gradient' ? {kind:'gradient',from:op.from,to:op.to,angleDeg:op.angleDeg,radial:op.radial}
            : op.kind === 'reset' ? {kind:'reset'} : {kind:'graphics',hidden:op.hidden};
        apply(indexes.map(slide => ({op:'setBackground',target:{slide},...common})));
        return renderAll();
    }, deleteElement: single('deleteElement', () => ({})), deleteElements: async (op: any) => { apply(op.sourceIds.map((id: string) => ({ op: 'deleteElement', target: target(op, id) }))); return render(op.slideIndex); },
    reorderElement: single('reorderElement', op => ({ direction: op.direction })), setElementFontSize: multi('setFont', 'font'),
    addBlankSlide: async (op: any) => { fitWidth = op.fitWidthPx ?? fitWidth; apply([{ op: 'addBlankSlide', target: { slide: op.sourceIndex } }]); return { slides: renderAll(), index: op.sourceIndex + 1 }; },
    duplicateSlides: async (op: any) => { apply([...(op.slideIndexes ?? op.slideIndices ?? op.indices ?? [])].sort((a, b) => b - a).map((slide: number) => ({ op: 'duplicateSlide', target: { slide } }))); return { slides: renderAll(), index: Math.max(...(op.slideIndexes ?? op.indices ?? [0])) + 1 }; }, deleteSlides: async (op: any) => { apply([...(op.slideIndexes ?? op.slideIndices ?? op.indices ?? [])].sort((a, b) => b - a).map((slide: number) => ({ op: 'deleteSlide', target: { slide } }))); return renderAll(); },
    getLayouts: async () => ({ layouts: listSlideLayouts(opened.archive).map((l: any) => ({ ...l, layoutType: l.type ?? 'blank', placeholders: l.placeholders ?? [] })), size: opened.deck.size }),
    addSlideWithLayout: async (op: any) => { apply([{ op: 'addSlideWithLayout', target: { slide: op.sourceIndex }, layout: op.layoutPath }]); return { slides: renderAll(), index: op.sourceIndex + 1 }; },
    getNotes: async (index: number) => getSlideNotes(opened.archive, opened.deck.slides[index].path), setNotes: async (op: any) => { undoStack.push(snapshot()); redoStack.length = 0; if (!setSlideNotes(opened, op.slideIndex, op.text))
        throw Error('Không lưu được ghi chú.'); metaDirty = true; notify(); return true; },
    getComments: async () => [], getSections: async () => [], getAnimations: async () => [], getSlideAnimations: async () => [], getEmbeddedFonts: async () => [], getFontMetrics: async () => null,
    undo: async () => { if (undoStack.length) {
        redoStack.push(snapshot());
        restore(undoStack.pop());
        preview = false;
        notify();
    } return renderAll(); }, redo: async () => { if (redoStack.length) {
        undoStack.push(snapshot());
        restore(redoStack.pop());
        notify();
    } return renderAll(); },
    save: () => save(), saveAs: () => save(true), writeMobileRecovery: (id: string) => save(false, id),
}, events);
installCommands(async (args: any) => { const result = await load(await readDocument(args.url), args.name); recovered = args.recovered === true; hasDocument = true; resolveInitial?.(result); resolveInitial = undefined; return { ...args, opened: result }; });
