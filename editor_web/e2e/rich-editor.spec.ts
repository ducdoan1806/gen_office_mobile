import {test,expect} from '@playwright/test';
import {readFile} from 'node:fs/promises';
import JSZip from 'jszip';
import {fixture} from '../tests/fixture';

test('original React/Tiptap renderer: open, rich edit, table edit, undo/redo, export and reopen',async({page})=>{
 const errors:string[]=[]; const external:string[]=[];
 page.on('pageerror',error=>errors.push(error.message));
 page.on('request',request=>{if(/^https?:/.test(request.url())&&!request.url().startsWith('http://127.0.0.1:5179'))external.push(request.url());});
 await page.goto('/');
 await expect(page.locator('.ProseMirror[contenteditable="true"]').first()).toBeVisible({timeout:30000});
 const chooserPromise=page.waitForEvent('filechooser');
 await page.locator('#browser-open').click();
 const chooser=await chooserPromise;
 await chooser.setFiles({name:'factory.docx',mimeType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',buffer:Buffer.from(await fixture())});
 const editor=page.locator('.ProseMirror[contenteditable="true"]').first();
 await expect(editor).toContainText('Xin chào nhà máy',{timeout:30000});
 const paragraph=editor.locator('p').filter({hasText:'Xin chào nhà máy'}).first();
 await paragraph.click(); await page.keyboard.press('End');
 await page.keyboard.press('ControlOrMeta+i'); await page.keyboard.insertText(' ca mới'); await page.keyboard.press('ControlOrMeta+i');
 await page.keyboard.press('Enter'); await page.keyboard.insertText('Đoạn thêm mới');
 await expect(editor).toContainText('Đoạn thêm mới');
 const cell=editor.locator('td').first(); await cell.click();await page.keyboard.press('End');await page.keyboard.insertText(' cập nhật');
 await expect(cell).toContainText('cập nhật');
 await page.locator('#browser-undo').click();await expect(cell).not.toContainText('cập nhật');
 await page.locator('#browser-redo').click();await expect(cell).toContainText('cập nhật');
 const downloadPromise=page.waitForEvent('download');await page.locator('#browser-save').click();const download=await downloadPromise;
 const bytes=await readFile((await download.path())!);const zip=await JSZip.loadAsync(bytes);const xml=await zip.file('word/document.xml')!.async('string');
 expect(xml).toContain('ca mới');expect(xml).toContain('Đoạn thêm mới');expect(xml).toContain('cập nhật');expect(xml).toMatch(/<w:i(?:\s|\/|>)/);
 expect(await zip.file('customXml/item1.xml')!.async('string')).toBe('<factory>keep-me</factory>');
 await page.evaluate(()=>{for(const element of document.querySelectorAll<HTMLElement>('*')){if(element.scrollTop)element.scrollTop=0;}});
 await page.screenshot({path:'/private/tmp/genoffice-rich-editor.png',fullPage:true});
 // Reload starts a fresh browser session and validates the actual exported bytes.
 page.on('dialog',dialog=>dialog.accept());
 await page.reload();await expect(page.locator('.ProseMirror[contenteditable="true"]').first()).toBeVisible();
 await page.locator('#browser-file').setInputFiles({name:'roundtrip.docx',mimeType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',buffer:bytes});
 await expect(page.locator('.ProseMirror[contenteditable="true"]').first()).toContainText('Đoạn thêm mới');
 expect(errors).toEqual([]);expect(external).toEqual([]);
});

for(const name of ['08-multi-section-paper.docx','15-mixed-content.docx']) {
 test(`upstream corpus opens and exports unchanged: ${name}`,async({page})=>{
  const errors:string[]=[];page.on('pageerror',error=>errors.push(error.message));
  await page.goto('/');await expect(page.locator('.ProseMirror[contenteditable="true"]').first()).toBeVisible({timeout:30000});
  const bytes=await readFile(new URL(`../tests/fixtures/${name}`,import.meta.url));
  await page.locator('#browser-file').setInputFiles({name,mimeType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',buffer:bytes});
  // A parser failure leaves a blank editor; require substantial loaded text.
  await expect.poll(async()=>await page.locator('.ProseMirror').first().innerText()).not.toBe('');
  await expect(page.locator('.status-bar')).not.toContainText('Failed');
  const sourceZip=await JSZip.loadAsync(bytes);
  const sourceXml=await sourceZip.file('word/document.xml')!.async('string');
  const firstText=sourceXml.match(/<w:t(?:\s[^>]*)?>([^<]+)<\/w:t>/)![1];
  await expect(page.locator('.ProseMirror').first()).toContainText(firstText,{timeout:30000});
  const promise=page.waitForEvent('download');await page.locator('#browser-save').click();const result=await promise;
  const saved=await readFile((await result.path())!);
  const original=await JSZip.loadAsync(bytes),after=await JSZip.loadAsync(saved);
  for(const [path,entry] of Object.entries(original.files)) {
   if(entry.dir)continue;
   expect(await after.file(path)!.async('uint8array'),path).toEqual(await entry.async('uint8array'));
  }
  expect(errors).toEqual([]);
 });
}
