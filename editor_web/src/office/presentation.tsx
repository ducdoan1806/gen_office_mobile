import React from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { buildRenderSlide, HeuristicMetrics } from '@genoffice/pptx-render';
import { Buffer } from 'buffer';
import { SlideCanvas } from '../../vendor/slides/src/renderer/SlideCanvas';
import { LocaleProvider, setModuleLang } from '../../vendor/slides/src/renderer/i18n/locale';
import type { OfficePackage } from './package';
let root: Root | undefined;
(window as any).slidesApi = { onLanguageChanged: () => () => { } };
setModuleLang('vi');
export function renderPresentation(container: HTMLElement, pack: OfficePackage, index: number, edit: (paragraph: number) => void) {
    root?.unmount();
    root = createRoot(container);
    const opened = pack.deck!, slide = opened.deck.slides[index];
    const images = new Map<string, HTMLImageElement>();
    const tree = buildRenderSlide(slide, opened.deck.size, { fitWidthPx: Math.max(300, Math.min(960, innerWidth - 24)), metrics: new HeuristicMetrics(), slideNo: index + 1, media(ref: string) { const bytes = opened.archive.readBytes(ref); if (!bytes)
            return; const ext = ref.split('.').pop()?.toLowerCase(); const mime = ({ png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', svg: 'image/svg+xml', webp: 'image/webp' } as any)[ext!]; return mime ? `data:${mime};base64,${Buffer.from(bytes).toString('base64')}` : undefined; } });
    const props: any = { slide: tree, selectedIds: [], images, onSelect: (id: string | null) => { props.selectedIds = id ? [id] : []; draw(); }, onEditText: (id: string) => { const fields = pack.paragraphs(index); const at = fields.findIndex(f => f.el.id === id); if (at >= 0)
            edit(at); }, onTransform: (id: string, b: any, preview: boolean) => { if (preview)
            return; const k = 9525 / tree.scale; pack.applyOperation({ op: 'setTransform', target: { slide: index, el: id }, box: { x: b.x * k, y: b.y * k, cx: b.w * k, cy: b.h * k }, rotDeg: b.rotationDeg }); renderPresentation(container, pack, index, edit); }, onEditTableCell: () => { }, onContextMenu: () => { }, onTableColResize: () => { } };
    const draw = () => root?.render(<LocaleProvider initial="vi"><SlideCanvas {...props}/></LocaleProvider>);
    const urls = new Set<string>();
    const collect = (n: any) => { if (!n)
        return; if (n.dataUrl)
        urls.add(n.dataUrl); if (n.fill?.dataUrl)
        urls.add(n.fill.dataUrl); n.children?.forEach(collect); };
    tree.nodes.forEach(collect);
    collect(tree.background);
    for (const url of urls) {
        const img = new Image();
        img.onload = () => { images.set(url, img); draw(); };
        img.src = url;
    }
    container.style.height = tree.heightPx + 'px';
    container.style.position = 'relative';
    draw();
}
export function disposePresentation() { root?.unmount(); root = undefined; }
