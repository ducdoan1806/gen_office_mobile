import type { installBrowserHost } from './browser-host';
interface NativeChannel { postMessage(message: string): void }
interface Command { id: string; method: string; args?: Record<string, unknown> }
interface NativeWindow extends Window { GenOfficeHost?: NativeChannel; genOfficeMobile?: { receive(command: Command): Promise<void> } }
const win = window as NativeWindow;
const send = (message: unknown) => win.GenOfficeHost?.postMessage(JSON.stringify(message));

/** Small, allowlisted host protocol. Document bytes stay on same-origin HTTP. */
export function installMobileHost(host: ReturnType<typeof installBrowserHost>): void {
 document.documentElement.dataset.host = 'mobile';
 const base = new URL('./', location.href);
 let currentName = 'document.docx';
 window.addEventListener('error',event=>send({type:'error',error:event.message}));
 window.addEventListener('unhandledrejection',event=>send({type:'error',error:String(event.reason)}));
 const localUrl = (value: unknown) => {
   const url = new URL(String(value), location.href);
   if (url.origin !== base.origin || !url.pathname.startsWith(base.pathname + 'documents/')) throw new Error('Invalid document URL');
   return url.href;
 };
 const pending = new Map<string,{resolve:(value:unknown)=>void;reject:(error:Error)=>void;timer:ReturnType<typeof setTimeout>}>();
 window.addEventListener('genoffice:reply', (event) => {
   const reply = (event as CustomEvent).detail;
   const item = pending.get(reply.id); if (!item) return;
   clearTimeout(item.timer); pending.delete(reply.id);
   reply.ok ? item.resolve(reply.value) : item.reject(new Error(reply.error));
 });
 window.addEventListener('genoffice:ready',()=>send({type:'ready',protocol:1}));
 const invokeRenderer = (command: Command) => new Promise<unknown>((resolve,reject)=>{
   const timer=setTimeout(()=>{pending.delete(command.id);reject(new Error('Renderer command timed out'));},45000);
   pending.set(command.id,{resolve,reject,timer});
   window.dispatchEvent(new CustomEvent('genoffice:command',{detail:command}));
 });
 win.genOfficeMobile = {async receive(command) {
   try {
     if (!command || typeof command.id !== 'string') throw new Error('Invalid command');
     if (!['open','save','undo','redo','status','new'].includes(command.method)) throw new Error('Unsupported command');
     if(command.method==='open') {
       const args=command.args!;
       command={...command,args:{file:{path:`mobile://${String(args.documentId)}`,name:String(args.name),dataUrl:localUrl(args.url),hash:''}}};
     }
     const value=await invokeRenderer(command);
     if(command.method==='open') currentName=String((command.args!.file as {name:string}).name);
     send({type:'reply',id:command.id,ok:true,value});
   } catch(error) { send({type:'reply',id:command.id,ok:false,error:String(error)}); }
 }};
 const save=async (name:string,data:ArrayBuffer,auto=false,copy=false)=>{
   if(auto)return {ok:false,error:'Use manual save in mobile host'};
   try {
     const url=new URL('exports',base);url.searchParams.set('name',name);
     if(copy)url.searchParams.set('mode','copy');
     const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/vnd.openxmlformats-officedocument.wordprocessingml.document'},body:data});
     const result=await response.json();
     if(!response.ok || !result.ok)throw new Error(result.error || 'Native save failed');
     currentName=result.name;
     send({type:'saved',name:result.name,path:result.path});
     return {ok:true,path:`mobile://saved/${encodeURIComponent(result.name)}`};
   }catch(error){return {ok:false,error:String(error)};}
 };
 host.api.saveDocx=(path:string,data:ArrayBuffer,auto:boolean)=>save(currentName,data,auto);
 host.api.saveDocxAs=(name:string,data:ArrayBuffer)=>save(name,data,false,true);
 host.api.saveDocxNew=(name:string,data:ArrayBuffer)=>save(name,data,false,true);
 // Native Flutter owns file selection and discard confirmation.
 host.api.openDocx=async()=>{send({type:'pickDocument'});return null;};
 host.api.confirmDocumentReplace=async()=>{send({type:'confirmRequired'});return false;};
 host.api.print=async()=>({ok:false,error:'Printing is not integrated on mobile yet'});
 host.api.pickImage=async()=>null;
}
