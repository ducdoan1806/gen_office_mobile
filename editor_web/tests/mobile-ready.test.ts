import {it,expect,vi,afterEach} from 'vitest';
afterEach(()=>vi.unstubAllGlobals());
it('queues commands while the React editor detaches its receiver during document changes',async()=>{
 const target=new EventTarget() as any;const replies:any[]=[];target.GenOfficeHost={postMessage:(raw:string)=>replies.push(JSON.parse(raw))};
 vi.stubGlobal('window',target);vi.stubGlobal('document',{documentElement:{dataset:{}}});vi.stubGlobal('location',{href:'http://127.0.0.1:8000/editor/'});
 const {installMobileHost}=await import('../src/platform/mobile-host');installMobileHost({api:{}} as any);
 const received:string[]=[];target.addEventListener('genoffice:command',(event:any)=>{received.push(event.detail.id);target.dispatchEvent(new CustomEvent('genoffice:reply',{detail:{id:event.detail.id,ok:true,value:{dirty:false}}}));});
 const first=target.genOfficeMobile.receive({id:'a',method:'status'});expect(received).toEqual([]);
 target.dispatchEvent(new Event('genoffice:ready'));await first;expect(received).toEqual(['a']);
 target.dispatchEvent(new Event('genoffice:not-ready'));const second=target.genOfficeMobile.receive({id:'b',method:'status'});expect(received).toEqual(['a']);
 target.dispatchEvent(new Event('genoffice:ready'));await second;expect(received).toEqual(['a','b']);expect(replies.filter(x=>x.type==='reply').every(x=>x.ok)).toBe(true);
});
