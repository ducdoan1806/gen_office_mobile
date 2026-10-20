import { describe, it, expect } from 'vitest';
import JSZip from 'jszip';
import { DocxSession } from '../src/core/docx-session';
import { fixture } from './fixture';
describe('browser DOCX session', () => {
 it('returns original bytes when unchanged', async () => {
  const bytes=await fixture();
  const session=await DocxSession.open({name:'sample.docx',bytes});
  expect(session.paragraphs[0].editable).toBe(true);
  expect((await session.export()).bytes).toEqual(bytes);
 });
 it('patches Vietnamese text, preserves formatting, links, tables and other parts; reopens', async () => {
  const original=await fixture();
  const session=await DocxSession.open({name:'sample.docx',bytes:original});
  session.setText(0,'Xin chào nhà máy & an toàn');
  const result=await session.export();
  const before=await JSZip.loadAsync(original), after=await JSZip.loadAsync(result.bytes);
  const xml=await after.file('word/document.xml')!.async('string');
  expect(xml).toContain('Xin chào nhà máy &amp; an toàn');
  expect(xml).toContain('<w:b/>');
  expect(xml).toContain('Giữ liên kết');
  expect(xml).toContain('Ô được giữ');
  for(const name of Object.keys(before.files)) {
   if(name==='word/document.xml' || before.files[name].dir) continue;
   expect(await after.file(name)!.async('uint8array')).toEqual(await before.file(name)!.async('uint8array'));
  }
  const reopened=await DocxSession.open(result);
  expect(reopened.paragraphs[0].text).toBe('Xin chào nhà máy & an toàn');
 });
 it('rejects unsupported edits and resets changes', async () => {
  const session=await DocxSession.open({name:'sample.docx',bytes:await fixture()});
  expect(session.paragraphs[1].editable).toBe(false);
  expect(()=>session.setText(1,'x')).toThrow();
  expect(()=>session.setText(0,'x\ny')).toThrow();
  session.setText(0,'Thay đổi'); expect(session.dirty).toBe(true);
  session.reset(); expect(session.dirty).toBe(false);
  expect(session.paragraphs[0].text).toBe('Xin chào nhà máy');
 });
 it('rejects invalid files', async () => {
  await expect(DocxSession.open({name:'bad.docx',bytes:new Uint8Array([1,2,3])})).rejects.toThrow();
 });
});
