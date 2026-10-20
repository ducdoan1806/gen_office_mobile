import { DocxSession } from './core/docx-session';
import { BrowserDocumentStorage } from './platform/browser-document-storage';
import './style.css';
const storage = new BrowserDocumentStorage();
const input = document.querySelector<HTMLInputElement>('#file')!;
const save = document.querySelector<HTMLButtonElement>('#save')!;
const reset = document.querySelector<HTMLButtonElement>('#reset')!;
const status = document.querySelector<HTMLElement>('#status')!;
const blocks = document.querySelector<HTMLElement>('#blocks')!;
let session: DocxSession | undefined;
let busy = false;
function render() {
  blocks.replaceChildren();
  for (const paragraph of session?.paragraphs ?? []) {
    const label = document.createElement('label');
    label.textContent = `${paragraph.id + 1}. ${paragraph.type}${paragraph.editable ? '' : ' · chỉ đọc'}`;
    const area = document.createElement('textarea');
    area.value = paragraph.text || '[Cấu trúc phi văn bản được giữ trong file]';
    if (paragraph.editable) area.value = paragraph.text;
    area.readOnly = !paragraph.editable;
    area.setAttribute('aria-label', `Đoạn ${paragraph.id + 1}`);
    area.addEventListener('input', () => {
      try { session!.setText(paragraph.id, area.value); status.textContent = 'Đã thay đổi • chưa xuất file'; }
      catch (error) { area.value = session!.paragraphs.find(p => p.id === paragraph.id)!.text; status.textContent = String(error); }
    });
    label.append(area); blocks.append(label);
  }
  save.disabled = !session || busy; reset.disabled = !session || busy;
}
input.addEventListener('change', async () => {
  const file = input.files?.[0];
  if (!file || busy) return;
  if (session?.dirty && !confirm('Bỏ các thay đổi chưa xuất để mở file khác?')) { input.value = ''; return; }
  busy = true; input.disabled = true; save.disabled = reset.disabled = true;
  blocks.inert = true; status.textContent = 'Đang mở…';
  try { const next = await DocxSession.open(await storage.read(file)); session = next; status.textContent = `Đã mở ${session.name}`; }
  catch (error) { status.textContent = `Không mở được tài liệu: ${error}`; }
  finally { busy = false; input.disabled = false; input.value = ''; blocks.inert = false; render(); }
});
save.addEventListener('click', async () => {
  if (!session || busy) return;
  busy = true; input.disabled = true; blocks.inert = true; render();
  try { await storage.write(await session.export()); status.textContent = 'Đã yêu cầu tải bản DOCX. Thay đổi vẫn giữ trong phiên hiện tại.'; }
  catch (error) { status.textContent = `Không xuất được file: ${error}`; }
  finally { busy = false; input.disabled = false; blocks.inert = false; save.disabled = false; reset.disabled = false; }
});
reset.addEventListener('click', () => { session?.reset(); render(); status.textContent = 'Đã khôi phục nội dung ban đầu.'; });
window.addEventListener('beforeunload', event => { if (session?.dirty) event.preventDefault(); });
