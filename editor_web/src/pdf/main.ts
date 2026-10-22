import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs';
import workerUrl from 'pdfjs-dist/legacy/build/pdf.worker.min.mjs?url';
import 'pdfjs-dist/web/pdf_viewer.css';
import './style.css';

// The viewer consumes the same core instance/version, including legacy polyfills.
(globalThis as any).pdfjsLib = pdfjs;
const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const status = element('status');
const tellHost = (type: string, value?: unknown) => (window as any).GenOfficePdf?.postMessage(JSON.stringify({type, value}));
function fail(message: string) { status.textContent = message; tellHost('error', message); }
const abort = new AbortController();
let loading: ReturnType<typeof pdfjs.getDocument> | undefined;
try {
  const {EventBus, PDFLinkService, PDFFindController, PDFViewer} = await import('pdfjs-dist/web/pdf_viewer.mjs');
  pdfjs.GlobalWorkerOptions.workerSrc = workerUrl;
  const bus = new EventBus();
  const link = new PDFLinkService({eventBus: bus});
  link.externalLinkEnabled = false;
  const find = new PDFFindController({eventBus: bus, linkService: link});
  const viewer = new PDFViewer({container: element<HTMLDivElement>('viewerContainer'), eventBus: bus,
    linkService: link, findController: find, annotationMode: pdfjs.AnnotationMode.DISABLE,
    maxCanvasPixels: 8 * 1024 * 1024, maxCanvasDim: 8192, enableDetailCanvas: false,
    enableAutoLinking: false, abortSignal: abort.signal});
  link.setViewer(viewer);
  const page = element<HTMLInputElement>('page');
  let ready = false;
  const controls = [...document.querySelectorAll<HTMLInputElement | HTMLButtonElement>('input,button')];
  controls.forEach(control => control.disabled = true);
  function updatePage() {
    page.value = String(viewer.currentPageNumber);
    element<HTMLButtonElement>('previous').disabled = viewer.currentPageNumber <= 1;
    element<HTMLButtonElement>('next').disabled = viewer.currentPageNumber >= viewer.pagesCount;
    tellHost('page', {page: viewer.currentPageNumber, total: viewer.pagesCount});
  }
  bus.on('pagesinit', () => {
    ready = true;
    viewer.currentScaleValue = 'page-width';
    controls.forEach(control => control.disabled = false);
    page.max = String(viewer.pagesCount);
    element('total').textContent = `/ ${viewer.pagesCount}`;
    status.textContent = 'PDF chỉ đọc · Tìm kiếm áp dụng cho chữ có sẵn trong file.';
    updatePage();
  });
  bus.on('pagerendered', ({pageNumber, error}: any) => {
    if (error) fail('Không hiển thị được trang PDF này.');
    else { tellHost('rendered', pageNumber); }
  });
  bus.on('pagechanging', updatePage);
  const showMatches = ({matchesCount}: any) => {
    const {current, total} = matchesCount;
    status.textContent = total ? `Kết quả ${current}/${total}` : 'Không tìm thấy chữ. PDF dạng ảnh cần OCR để tìm kiếm.';
    tellHost('matches', {current, total});
  };
  bus.on('updatefindmatchescount', showMatches);
  bus.on('updatefindcontrolstate', (event: any) => {
    if (event.state === 3) status.textContent = 'Đang tìm kiếm…';
    else showMatches(event);
  });
  element('previous').onclick = () => viewer.currentPageNumber = Math.max(1, viewer.currentPageNumber - 1);
  element('next').onclick = () => viewer.currentPageNumber = Math.min(viewer.pagesCount, viewer.currentPageNumber + 1);
  page.onchange = () => {
    const number = Number(page.value);
    if (Number.isInteger(number) && number >= 1 && number <= viewer.pagesCount) viewer.currentPageNumber = number;
    else { status.textContent = `Nhập số trang từ 1 đến ${viewer.pagesCount}.`; page.value = String(viewer.currentPageNumber); }
    page.blur();
  };
  element('zoomIn').onclick = () => viewer.currentScale = Math.min(4, viewer.currentScale * 1.25);
  element('zoomOut').onclick = () => viewer.currentScale = Math.max(0.25, viewer.currentScale / 1.25);
  element('fit').onclick = () => viewer.currentScaleValue = 'page-width';
  const query = element<HTMLInputElement>('query');
  function search(again = false, previous = false) {
    if (!ready) return;
    if (!query.value.trim()) {
      bus.dispatch('findbarclose', {});
      status.textContent = 'Nhập chữ cần tìm trong PDF.';
      return;
    }
    bus.dispatch('find', {source: window, type: again ? 'again' : '', query: query.value.trim(),
      caseSensitive: false, entireWord: false, highlightAll: true, findPrevious: previous, matchDiacritics: false});
  }
  element('searchForm').onsubmit = event => {event.preventDefault(); query.blur(); search();};
  element('findPrevious').onclick = () => search(true, true);
  element('findNext').onclick = () => search(true);
  query.oninput = () => { if (!query.value) search(); };
  const relative = new URLSearchParams(location.search).get('file') || '';
  const url = new URL(relative, location.href);
  const base = new URL('./', location.href);
  if (url.origin !== base.origin || !url.pathname.startsWith(`${base.pathname}documents/`)) throw new Error('Invalid PDF URL');
  loading = pdfjs.getDocument({url: url.href, cMapUrl: new URL('pdf/cmaps/', base).href,
    cMapPacked: true, standardFontDataUrl: new URL('pdf/standard_fonts/', base).href,
    wasmUrl: new URL('pdf/wasm/', base).href, iccUrl: new URL('pdf/iccs/', base).href,
    isEvalSupported: false, maxImageSize: 16 * 1024 * 1024});
  // Password PDFs fail explicitly; no password is stored or sent to native code.
  loading.onPassword = () => { void loading?.destroy(); fail('PDF có mật khẩu. Hãy mở bản PDF không đặt mật khẩu.'); };
  const pdf = await loading.promise;
  viewer.setDocument(pdf);
  link.setDocument(pdf);
  window.addEventListener('pagehide', () => { abort.abort(); viewer.setDocument(null); void loading?.destroy(); }, {once: true});
} catch (error) {
  if (!status.textContent?.startsWith('PDF có mật khẩu')) fail('Không mở được PDF. File có thể bị hỏng hoặc không được hỗ trợ.');
  console.error(error);
}
