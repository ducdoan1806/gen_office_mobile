import {test,expect,type Page} from '@playwright/test';
import {readFileSync} from 'node:fs';
import JSZip from 'jszip';
const fixture=(name:string)=>readFileSync(new URL('../../assets/samples/'+name,import.meta.url));
async function setup(page:Page,kind:'xlsx'|'pptx'|'pdf'){
 const errors:string[]=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.addInitScript(()=>{const w=window as any;w.qaMessages=[];w.GenOfficeHost={postMessage:(s:string)=>w.qaMessages.push(JSON.parse(s))};w.GenOfficePdf={postMessage:(s:string)=>w.qaMessages.push(JSON.parse(s))};});
 const name=kind==='xlsx'?'sheets-test.xlsx':kind==='pptx'?'slides-test.pptx':'pdf-viewer-test.pdf';
 await page.route('**/documents/fixture*',route=>route.fulfill({body:fixture(name),contentType:kind==='pdf'?'application/pdf':'application/octet-stream'}));
 const writes:Buffer[]=[],writeModes:string[]=[];await page.route('**/exports?*',route=>{writes.push(route.request().postDataBuffer()!);writeModes.push(new URL(route.request().url()).searchParams.get('mode')||'save');return route.fulfill({json:{ok:true,name,path:'qa-'+name}});});
 await page.goto(kind==='pdf'?'/pdf.html?file=documents/fixture.pdf':'/office.html?format='+kind);
 await expect.poll(async()=>errors.length>0||await page.evaluate(()=>(window as any).qaMessages.some((m:any)=>m.type==='ready'||m.type==='rendered'||m.type==='error')),{timeout:30000}).toBe(true);expect(errors).toEqual([]);expect(await page.evaluate(()=>(window as any).qaMessages.filter((m:any)=>m.type==='error'))).toEqual([]);
 if(kind!=='pdf')await command(page,'open',{url:new URL('/documents/fixture',page.url()).href,name,documentId:'fixture'});
 await expect(page.locator('.ribbon-tabs .qa-btn:visible,.ribbon-tabs .autosave-toggle:visible')).toHaveCount(0);
 return{errors,writes,writeModes,name};
}
let sequence=0;
async function command(page:Page,method:string,args?:any){const id='qa-'+(++sequence);await page.evaluate(({id,method,args})=>(window as any).genOfficeMobile.receive({id,method,args}),{id,method,args});const reply=await page.evaluate(id=>(window as any).qaMessages.find((m:any)=>m.id===id),id);expect(reply,method).toMatchObject({ok:true});return reply.value;}
async function mobileScreenshot(page:Page,path:string){await page.setViewportSize({width:390,height:800});await page.screenshot({path:test.info().outputPath(path),fullPage:true});expect(await page.locator('.ribbon-tabs').evaluate(el=>el.scrollWidth>el.clientWidth)).toBe(true);await page.locator('.ribbon-tabs').evaluate(el=>el.scrollLeft=el.scrollWidth);expect(await page.locator('.ribbon-tabs').evaluate(el=>el.scrollLeft)).toBeGreaterThan(0);}
test('original Sheets App: ribbon formatting, formula, save and reload',async({page})=>{
 const {errors,writes,writeModes}=await setup(page,'xlsx');await expect(page.getByRole('button',{name:'Trang đầu',exact:true})).toBeVisible();
 await page.waitForFunction(()=>(window as any).genOfficeSheets?.getActiveWorkbook());
 await page.evaluate(()=>{const b=(window as any).genOfficeSheets.getActiveWorkbook(),s=b.getSheets()[0];b.setActiveSheet(s);s.getRange('B2').setValue(25);s.getRange('E2').setValue('=SUM(B2:C2)');s.getRange('B2').activate();});
 await expect.poll(()=>page.evaluate(()=>(window as any).genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange('D2').getValue())).toBe(33);
 await page.locator('.inline-tools button').filter({has:page.locator('b')}).first().click();
 await command(page,'save');expect(writes).toHaveLength(1);const zip=await JSZip.loadAsync(writes[0]);expect(await zip.file('xl/worksheets/sheet1.xml')!.async('string')).toContain('>25<');
 expect(await zip.file('xl/worksheets/sheet1.xml')!.async('string')).toMatch(/<c[^>]*r="E2"[^>]*>[\s\S]*?<v>33<\/v>[\s\S]*?<\/c>/);
 const before=await JSZip.loadAsync(fixture('sheets-test.xlsx'));for(const name of Object.keys(before.files).filter(n=>n.startsWith('xl/charts/')&&!before.files[n].dir))expect(await zip.file(name)!.async('uint8array')).toEqual(await before.file(name)!.async('uint8array'));
 await page.route('**/documents/edited*',route=>route.fulfill({body:writes[0],contentType:'application/octet-stream'}));
 await command(page,'open',{url:new URL('/documents/edited',page.url()).href,name:'edited.xlsx',documentId:'fixture'});
 await expect.poll(()=>page.evaluate(()=>(window as any).genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange('B2').getValue())).toBe(25);
 await expect.poll(()=>page.evaluate(()=>(window as any).genOfficeSheets.getActiveWorkbook().getSheets()[0].getRange('D2').getValue())).toBe(33);
 await command(page,'open',{url:new URL('/documents/edited',page.url()).href,name:'edited.xlsx',documentId:'fixture',recovered:true});
 expect(await command(page,'status')).toMatchObject({dirty:true});await command(page,'save');expect(await command(page,'status')).toMatchObject({dirty:false});
 await command(page,'saveAs');expect(writeModes.at(-1)).toBe('copy');
 await mobileScreenshot(page,'sheets-mobile.png');expect(errors).toEqual([]);
});
test('original Slides App: canvas text editor, add slide, history and save',async({page})=>{
 const {errors,writes,writeModes}=await setup(page,'pptx');await expect(page.getByRole('button',{name:'Trang chủ',exact:true})).toBeVisible();
 const tree=await page.evaluate(async()=>(window as any).slidesApi.getRenderSlides());const node=tree[0].nodes.find((n:any)=>n.type==='text');expect(node).toBeTruthy();const canvas=page.locator('.konvajs-content').last();await expect(canvas).toBeVisible();const box=await canvas.boundingBox();const scale=box!.width/(tree[0].widthPx+320);const x=box!.x+(node.box.x+160+node.box.w/2)*scale,y=box!.y+(node.box.y+160+node.box.h/2)*scale;
 await page.mouse.dblclick(x,y);const edit=page.locator('.slide-text-editor');await expect(edit).toBeVisible();await edit.fill('Báo cáo từ giao diện GenOffice');
 await command(page,'save');expect(writes).toHaveLength(1);let zip=await JSZip.loadAsync(writes[0]);expect(await zip.file('ppt/slides/slide1.xml')!.async('string')).toContain('Báo cáo từ giao diện GenOffice');
 await page.getByRole('button',{name:'Trang chiếu',exact:true}).click();await page.locator('button[data-tip-kbd="Ctrl+M"],button[data-tip-kbd="⇧⌘N"]').first().click();await expect.poll(()=>page.evaluate(async()=>(await(window as any).slidesApi.getRenderSlides()).length)).toBe(3);await command(page,'undo');await expect.poll(()=>page.evaluate(async()=>(await(window as any).slidesApi.getRenderSlides()).length)).toBe(2);await command(page,'redo');await expect.poll(()=>page.evaluate(async()=>(await(window as any).slidesApi.getRenderSlides()).length)).toBe(3);
 await command(page,'save');zip=await JSZip.loadAsync(writes[1]);const before=await JSZip.loadAsync(fixture('slides-test.pptx'));for(const name of Object.keys(before.files).filter(n=>/ppt\/(media|notesSlides)\//.test(n)&&!before.files[n].dir))expect(await zip.file(name)!.async('uint8array')).toEqual(await before.file(name)!.async('uint8array'));
 await command(page,'saveAs');expect(writeModes.at(-1)).toBe('copy');
 await mobileScreenshot(page,'slides-mobile.png');expect(errors).toEqual([]);
});
test('original PDF App: thumbnails, search, page navigation and mobile ribbon',async({page})=>{
 const {errors,writes}=await setup(page,'pdf');await expect(page.locator('.pdf-page').first()).toBeVisible();await page.getByRole('button',{name:'Tìm kiếm',exact:true}).first().click();const input=page.locator('.pdf-search-input');await expect(input).toBeVisible();await input.fill('Factory');await page.waitForTimeout(800);await expect(page.locator('.pdf-search-input')).toHaveValue('Factory');await expect(page.locator('.tb-readonly')).toContainText('Chế độ xem PDF');
 await mobileScreenshot(page,'pdf-mobile.png');await page.locator('.pdf-thumb[data-idx="2"]').click();await expect(page.locator('.pdf-thumb-active')).toHaveAttribute('data-idx','2');expect(writes).toEqual([]);expect(errors).toEqual([]);
});

test('touch grid pans with axis lock and inertia without selecting cells',async({page})=>{
 await setup(page,'xlsx');await page.setViewportSize({width:390,height:800});
 await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
 await page.evaluate(()=>{const sheet=(window as any).genOfficeSheets.getActiveWorkbook().getActiveSheet();sheet.getRange('B2').activate();});
 const canvas=page.locator('#univer-container canvas').last(),box=(await canvas.boundingBox())!;
 const client=await page.context().newCDPSession(page);
 const start=async(x:number,y:number)=>client.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});
 const move=async(x:number,y:number)=>client.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y,id:1}]});
 const end=async()=>client.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 const state=()=>page.evaluate(()=>(window as any).genOfficeSheets.getActiveWorkbook().getActiveSheet().getScrollState());
 const x=box.x+250,y=box.y+Math.min(350,box.height-50);
 await start(x,y);for(let i=1;i<=8;i++){await move(x+2,y-i*20);await page.waitForTimeout(18);}await end();
 await expect.poll(async()=>(await state()).sheetViewStartRow).toBeGreaterThan(0);
 const first=await state();await page.waitForTimeout(200);const coast=await state();expect(coast.sheetViewStartRow).toBeGreaterThanOrEqual(first.sheetViewStartRow);
 await page.waitForTimeout(1200);const before=await state();
 await start(x,y);for(let i=1;i<=6;i++){await move(x-i*22,y+2);await page.waitForTimeout(18);}await end();
 await expect.poll(async()=>(await state()).sheetViewStartColumn).toBeGreaterThan(0);
 expect((await state()).sheetViewStartRow).toBe(before.sheetViewStartRow);
 expect(await page.evaluate(()=>(window as any).genOfficeSheets.getActiveWorkbook().getActiveSheet().getActiveRange()?.getA1Notation())).toBe('B2');
 await client.detach();
});

for (const androidOffsets of [false,true]) {
test('touch tap selects, long press selects a range, double tap edits'+(androidOffsets?' with Android WebView scaled offsets':''),async({page})=>{
 if(androidOffsets)await page.addInitScript(()=>{
  // Reproduce WebView's extra page-scale conversion of synthetic offsets.
  // Own canvas-local offsets must win over these incorrect derived values.
  for(const key of ['offsetX','offsetY'] as const){
   const native=Object.getOwnPropertyDescriptor(MouseEvent.prototype,key)!;
   Object.defineProperty(MouseEvent.prototype,key,{configurable:true,get(){
    const target=this.target as HTMLElement;
    if(!this.isTrusted && this.type.startsWith('pointer') && target?.id?.startsWith('univer-sheet-main-canvas_')){
     const rect=target.getBoundingClientRect();return key==='offsetX'?this.clientX/1.875-rect.left:this.clientY/1.875-rect.top;
    }
    return native.get!.call(this);
   }});
  }
 });
 await setup(page,'xlsx');await page.setViewportSize({width:390,height:800});await page.waitForTimeout(250);
 const client=await page.context().newCDPSession(page);
 const point=async(ref:string)=>{
  const r=await page.evaluate(ref=>{const r=(window as any).genOfficeSheets.getActiveWorkbook().getActiveSheet().getRange(ref).getCellRect();return{x:r.x+r.width/2,y:r.y+r.height/2};},ref);
  const box=(await page.locator('#univer-container canvas').last().boundingBox())!;return{x:box.x+r.x,y:box.y+r.y};
 };
 const touch=async(type:string,p?:{x:number,y:number})=>client.send('Input.dispatchTouchEvent',{type,touchPoints:p?[{...p,id:1}]:[]});
 const active=()=>page.evaluate(()=>(window as any).genOfficeSheets.getActiveWorkbook().getActiveSheet().getActiveRange()?.getA1Notation());
 const b2=await point('B2');await touch('touchStart',b2);await touch('touchEnd');await expect.poll(active).toBe('B2');
 await page.waitForTimeout(400);await touch('touchStart',b2);await page.waitForTimeout(450);await touch('touchMove',await point('C3'));await touch('touchEnd');await expect.poll(active).toBe('B2:C3');
 await page.waitForTimeout(400);await touch('touchStart',b2);await touch('touchEnd');await page.waitForTimeout(70);await touch('touchStart',b2);await touch('touchEnd');
 await expect(page.locator('[contenteditable="true"][id$="DOCS_NORMAL"]')).toBeFocused();
 await page.keyboard.press('Control+A');await page.keyboard.insertText('42');await page.keyboard.press('Enter');
 await expect.poll(()=>page.evaluate(()=>(window as any).genOfficeSheets.getActiveWorkbook().getActiveSheet().getRange('B2').getValue())).toBe(42);await client.detach();
});
}
