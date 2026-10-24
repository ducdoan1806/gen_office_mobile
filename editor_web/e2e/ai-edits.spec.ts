import {test,expect,type Page} from '@playwright/test';
import {readFileSync} from 'node:fs';
import JSZip from 'jszip';
import {fixture} from '../tests/fixture';
let seq=0;
async function command(page:Page,method:string,args?:any,ok=true){
 const id='ai-'+(++seq);await page.evaluate(payload=>(window as any).genOfficeMobile.receive(payload),{id,method,args});
 const reply=await page.evaluate(id=>(window as any).qaMessages.find((m:any)=>m.id===id),id);
 expect(reply,method).toMatchObject({ok});return reply.value;
}
for(const kind of ['docx','xlsx','pptx'] as const) {
 test(`AI ${kind}: guarded edit, undo, redo, save and reopen`,async({page})=>{
  test.setTimeout(120000);
  page.on('pageerror',e=>console.error('PAGE ERROR',e.message));
  page.on('console',m=>{if(m.type()==='error')console.error('BROWSER ERROR',m.text());});
  const original=kind==='docx'?Buffer.from(await fixture()):readFileSync(new URL(`../../assets/samples/${kind==='xlsx'?'sheets-test.xlsx':'slides-test.pptx'}`,import.meta.url));
  await page.addInitScript(()=>{const w=window as any;w.qaMessages=[];w.GenOfficeHost={postMessage:(s:string)=>w.qaMessages.push(JSON.parse(s))};});
  let source=original, output:Buffer|undefined;
  await page.route('**/documents/fixture',route=>route.fulfill({body:source}));
  await page.route('**/exports?*',route=>{output=route.request().postDataBuffer()!;return route.fulfill({json:{ok:true,name:`sample.${kind}`,path:'qa-file'}});});
  await page.goto(kind==='docx'?'/?mobile=1':`/office.html?format=${kind}`);
  await expect.poll(()=>page.evaluate(()=>(window as any).qaMessages.some((m:any)=>m.type==='ready')),{timeout:30000}).toBe(true);
  const open=()=>command(page,'open',{name:`sample.${kind}`,documentId:'fixture',url:new URL('/documents/fixture',page.url()).href});
  await open();
  if(kind==='xlsx') {
   await page.waitForFunction(()=>(window as any).genOfficeSheets?.getActiveWorkbook());
   const automatic = await command(page,'aiContext');
   expect(automatic.scope).toContain('Dữ liệu sheet hiện tại');
   expect(automatic.entries.length).toBeGreaterThan(1);
   await page.evaluate(()=>{const book=(window as any).genOfficeSheets.getActiveWorkbook();book.getSheets()[0].getRange('B2:C2').activate();});
  }
  const context=await command(page,'aiContext');
  expect(context.entries.length).toBeGreaterThan(0);
  const entry=context.entries.find((e:any)=>e.text.length>0)!;
  const changes=[{id:entry.id,before:entry.text,after:kind==='xlsx'?'42':entry.text+' AI changed'}];
  const followup = await command(page,'aiContext');
  expect(followup.revision).toBe(context.revision);
  await command(page,'aiApply',{revision:context.revision,changes});
  const modified=await command(page,'aiContext');
  expect(modified.entries.some((e:any)=>e.text===changes[0].after)).toBe(true);
  await command(page,'undo');
  const undone=await command(page,'aiContext');
  expect(undone.entries.some((e:any)=>e.text===entry.text)).toBe(true);
  await command(page,'redo');
  const redone=await command(page,'aiContext');
  expect(redone.entries.some((e:any)=>e.text===changes[0].after)).toBe(true);
  // A document change since the capture must invalidate a proposal.
  await command(page,'undo');
  await command(page,'aiApply',{revision:redone.revision,changes:[{id:entry.id,before:changes[0].after,after:'invalid'}]},false);
  await command(page,'redo');
  await command(page,'save');expect(output).toBeDefined();
  const oldZip=await JSZip.loadAsync(original),zip=await JSZip.loadAsync(output!);
  const editable=kind==='docx'?/^word\/document.xml$/:kind==='xlsx'?/^xl\/worksheets\/sheet1.xml$/:/^ppt\/slides\/slide1.xml$/;
  // Images, styles, themes, headers and other untouched parts retain their bytes.
  for(const [name,file] of Object.entries(oldZip.files)) if(!file.dir && !editable.test(name) &&
    !['[Content_Types].xml','docProps/core.xml','xl/calcChain.xml','xl/workbook.xml','xl/_rels/workbook.xml.rels','xl/sharedStrings.xml','xl/styles.xml'].includes(name)) {
    const target=zip.file(name);expect(target, name).not.toBeNull();
    expect(await target!.async('uint8array'),name).toEqual(await file.async('uint8array'));
  }
  source=output!;await open();
  if(kind==='xlsx')await page.evaluate(()=>{const book=(window as any).genOfficeSheets.getActiveWorkbook();book.getSheets()[0].getRange('B2:C2').activate();});
  const reopened=await command(page,'aiContext');
  expect(reopened.entries.some((e:any)=>e.text===changes[0].after)).toBe(true);
 });
}
