import { Buffer } from 'buffer';
(globalThis as any).Buffer = Buffer;
const format = new URLSearchParams(location.search).get('format');
try {
    if (format === 'xlsx') {
        (await import('./sheets-touch')).installSheetsTouch();
        await import('./sheets-host');
        await import('../../vendor/sheets/src/renderer/main');
    }
    else if (format === 'pptx') {
        await import('./slides-host');
        await import('../../vendor/slides/src/renderer/main');
    }
    else
        throw Error('Định dạng chưa hỗ trợ.');
}
catch (error) {
    document.getElementById('root')!.textContent = String(error);
    (window as any).GenOfficeHost?.postMessage(JSON.stringify({ type: 'error', error: String(error) }));
}
