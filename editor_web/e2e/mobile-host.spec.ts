import {test,expect} from '@playwright/test';
import JSZip from 'jszip';
import {fixture} from '../tests/fixture';

test('mobile protocol transfers DOCX bytes and reports native save failure',async({page})=>{
 await page.addInitScript(()=>{
  (window as any).nativeMessages=[];
  (window as any).GenOfficeHost={postMessage:(value:string)=>(window as any).nativeMessages.push(JSON.parse(value))};
 });
 await page.route('**/documents/sample',async route=>route.fulfill({body:Buffer.from(await fixture()),contentType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document'}));
 let output:Buffer|undefined;let failSave=false;
 await page.route('**/exports?*',async route=>{
  output=route.request().postDataBuffer()!;
  await route.fulfill({status:failSave?500:200,contentType:'application/json',body:JSON.stringify(failSave?{ok:false,error:'Disk full'}:{ok:true,name:'factory.docx',path:'/app/factory.docx'})});
 });
 await page.goto('/?mobile=1');
 await expect.poll(()=>page.evaluate(()=>(window as any).nativeMessages.some((event:any)=>event.type==='ready'))).toBe(true);
 let seq=0;
 async function command(method:string,args?:unknown){
  const id=`test-${++seq}`;
  await page.evaluate(async payload=>{await (window as any).genOfficeMobile.receive(payload);},{id,method,args});
  return page.evaluate(id=>(window as any).nativeMessages.find((event:any)=>event.type==='reply'&&event.id===id),id);
 }
 const opened=await command('open',{documentId:'sample',name:'factory.docx',url:'http://127.0.0.1:5179/documents/sample'});expect(opened.ok).toBe(true);
 const editor=page.locator('.ProseMirror[contenteditable="true"]').first();await expect(editor).toContainText('Xin chào nhà máy');
 const paragraph=editor.locator('p').filter({hasText:'Xin chào nhà máy'}).first();await paragraph.click();await page.keyboard.press('End');await page.keyboard.insertText(' native bridge');
 const saved=await command('save');expect(saved.ok).toBe(true);
 const zip=await JSZip.loadAsync(output!);expect(await zip.file('word/document.xml')!.async('string')).toContain('native bridge');
 await paragraph.click();await page.keyboard.press('End');await page.keyboard.insertText(' pending');
 failSave=true;const failure=await command('save');expect(failure.ok).toBe(false);
 expect((await command('status')).value.dirty).toBe(true);
 const denied=await command('open',{documentId:'bad',name:'bad.docx',url:'https://example.com/file.docx'});expect(denied.ok).toBe(false);
});
