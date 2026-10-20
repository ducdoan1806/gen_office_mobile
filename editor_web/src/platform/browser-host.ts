import type { DesktopApi, MenuCommand, OpenFileResult } from '../../vendor/docs/shared/ipc';
import { defaultAiSettings } from '../../vendor/ai-provider/src/providers';

type Listener = (...args: any[]) => void;
const MIME = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
interface StoredFile { path: string; name: string; bytes: Uint8Array }

/** Only host integration changes: the upstream editor retains its command/schema/save pipeline. */
export function installBrowserHost() {
  const listeners = new Map<string, Set<Listener>>();
  const files = new Map<string, StoredFile>();
  const handoffs = new Set<string>();
  let closeState = { dirty: false };
  const status = document.querySelector<HTMLElement>('#browser-status')!;
  const notify = (message: string) => { status.textContent = message; };
  const on = (event: string, fn: Listener) => {
    const set = listeners.get(event) ?? new Set<Listener>();
    set.add(fn); listeners.set(event, set);
    return () => { set.delete(fn); };
  };
  const emit = (event: string, ...args: any[]) => listeners.get(event)?.forEach(fn => fn(...args));
  const unsupported = (action: string) => {
    const error = `Chức năng chưa hỗ trợ trong browser adapter: ${action}`;
    notify(error); return {ok:false,error};
  };
  function handoff(file: StoredFile): OpenFileResult {
    const url = URL.createObjectURL(new Blob([new Uint8Array(file.bytes)],{type:MIME}));
    handoffs.add(url);
    return {path:file.path,name:file.name,dataUrl:url,hash:''};
  }
  async function importFile(file: File): Promise<OpenFileResult> {
    if (!/\.docx$/i.test(file.name)) throw new Error('Chỉ hỗ trợ DOCX.');
    if (file.size > 20*1024*1024) throw new Error('Giới hạn bản web hiện tại là 20 MB.');
    const stored = {path:`browser://${crypto.randomUUID()}/${file.name}`,name:file.name,bytes:new Uint8Array(await file.arrayBuffer())};
    files.set(stored.path,stored);
    notify(`Đã đọc ${file.name}; đang mở trong editor…`);
    return handoff(stored);
  }
  function confirmReplace(): boolean {
    emit('onCloseCheck');
    return !closeState.dirty || confirm('Tài liệu có thay đổi chưa lưu. Bỏ thay đổi để tiếp tục?');
  }
  async function chooseFile(): Promise<OpenFileResult|null> {
    return new Promise(resolve => {
      const input=document.createElement('input'); input.type='file';input.accept='.docx';
      input.addEventListener('change',async () => {
        try {resolve(input.files?.[0] ? await importFile(input.files[0]) : null);}
        catch(error){notify(String(error));resolve(null);}
      },{once:true});
      input.addEventListener('cancel',()=>resolve(null),{once:true}); input.click();
    });
  }
  async function download(path: string|null, name: string, data: ArrayBuffer, auto=false) {
    if(auto) return {ok:false,error:'Browser autosave is disabled. Use manual download.'};
    const bytes=new Uint8Array(data.slice(0));
    const fileName=/\.docx$/i.test(name)?name:`${name}.docx`;
    const target=path ?? `browser://${crypto.randomUUID()}/${fileName}`;
    const url=URL.createObjectURL(new Blob([bytes],{type:MIME}));
    const link=document.createElement('a');link.href=url;link.download=fileName;document.body.append(link);link.click();link.remove();
    setTimeout(()=>URL.revokeObjectURL(url),30_000);
    files.set(target,{path:target,name:fileName,bytes});
    notify(`Đã gửi ${fileName} tới trình tải xuống. Kiểm tra thư mục Downloads.`);
    return {ok:true,path:target};
  }
  const api: Record<string, any> = {
    getLanguage:async()=> 'vi', getSystemLocale:async()=>navigator.language,
    getTheme:async()=> 'system', getDocumentTheme:async()=> 'follow',
    getAuthorName:async()=> 'Người dùng',getAiPanelPrefs:async()=>({}),
    getAutoSaveDefault:async()=>({on:false,updatedAt:1}),
    getAiSettings:async()=>({...defaultAiSettings(),gskToolsEnabled:false}),
    getRecentFiles:async()=>Array.from(files.keys()).reverse(),
    openDocx:chooseFile,
    openDocxPath:async(path:string)=>files.has(path)?handoff(files.get(path)!):null,
    confirmDocumentReplace:async()=>confirmReplace(),
    consumePendingOpenDocx:async()=>null,consumeNewBlankDoc:async()=>false,
    consumeAiDocContent:async()=>null,consumeHeadlessExport:async()=>null,
    docPasswordIntentRevision:async()=>0,discardDocPasswordIntents:async()=>{},
    saveDocx:(path:string,data:ArrayBuffer,auto:boolean)=>download(path,files.get(path)?.name ?? 'document.docx',data,auto),
    saveDocxAs:(name:string,data:ArrayBuffer)=>download(null,name,data),
    saveDocxNew:(name:string,data:ArrayBuffer)=>download(null,name,data),
    saveDocxTo:async()=>unsupported('ghi đường dẫn hệ điều hành'),
    writeRecoveryCopy:async()=>({ok:false}),
    reportCloseCheck:(state:{dirty:boolean})=>{closeState=state;},
    reportCloseSaveResult:()=>{},reportViewMenuState:()=>{},
    armContextMenu:()=>{},claimContextMenu:()=>{},spellDiag:()=>{},respellKick:async()=>{},
    spellLanguages:async()=>({available:[],active:[]}),spellSetLanguages:async()=>({available:[],active:[]}),
    fontMetrics:async()=>null,
    getPathForFile:()=>'',listDocsTabs:async()=>[],
    signalMcpReady:()=>{},reportMcpResult:()=>{},headlessExportDone:()=>{},respondToZotero:()=>{},
    print:async()=>{window.print();return {ok:true};},listPrinters:async()=>[],
    setDocPassword:async()=>unsupported('mã hóa file'),
    openDocxDecrypt:async()=>({ok:false,reason:'unsupported',error:'Encrypted DOCX is not supported in browser.'}),
    openSourcePath:async()=>unsupported('mở đường dẫn hệ điều hành'),
    openNewTab:async()=>unsupported('tab desktop'),focusDocsTab:async()=>false,
    pickImage:async()=>new Promise(resolve=>{
      const picker=document.createElement('input');picker.type='file';picker.accept='image/png,image/jpeg,image/gif';
      picker.addEventListener('cancel',()=>resolve(null),{once:true});
      picker.addEventListener('change',async()=>{
        const file=picker.files?.[0];if(!file){resolve(null);return;}
        if(file.size>10*1024*1024){notify('Ảnh vượt giới hạn 10 MB.');resolve(null);return;}
        const reader=new FileReader();reader.onload=()=>resolve({name:file.name,mime:file.type,base64:String(reader.result).split(',')[1]});reader.onerror=()=>resolve(null);reader.readAsDataURL(file);
      },{once:true});picker.click();
    }),
    fetchImage:async()=>unsupported('tải ảnh bên ngoài'),
    saveImageAs:async()=>unsupported('xuất ảnh'),
    copyImageToClipboard:async()=>unsupported('clipboard ảnh'),
    exportPdf:async()=>unsupported('PDF qua Electron; dùng in trình duyệt'),
    saveMergedPdf:async()=>unsupported('ghép PDF'),pickExportImagesTarget:async()=>null,
    takeExportPdf:async()=>unsupported('xuất PDF'),writeExportImage:async()=>unsupported('xuất ảnh'),
    exportHtml:async()=>unsupported('xuất HTML'),exportMarkdown:async()=>unsupported('xuất Markdown'),
    spellAddWord:async()=>false,spellIgnoreWord:async()=>false,spellReplace:async()=>unsupported('native spellcheck'),
    zoteroCommand:async()=>unsupported('Zotero desktop'),
    setAiPanelPrefs:async()=>({}),
    skillsList:async()=>[],
    aiGskStatus:async()=>({loggedIn:false}),
  };
  // Native event subscriptions have a browser event bus, not an IPC bridge.
  for (const name of ['onLanguageChanged','onThemeChanged','onDocumentThemeChanged','onAutoSaveDefaultChanged','onAuthorNameChanged','onAiPanelPrefsChanged','onChromePressed','onZoteroRequest','onOpenDocx','onRenamedDocx','onTeardown','onContextMenuRequest','onMcpCommand','onViewImage','onAiSettingsChanged','onAiStream','onMenuCommand','onCloseCheck','onCloseSaveRequest']) {
    api[name]=(handler:Listener)=>on(name,handler);
  }
  // Explicitly reject all model/network/CLI actions; factory AI is untouched.
  for(const name of ['aiChat','aiStream','aiStreamCancel','aiGskLogin','webSearch','imageSearch','analyzeMedia','aiGenerateImage','openAiModelSettings','setAiSettings','runCli','skillText','pickAttachments','addAttachmentPaths','addPastedImage','readAttachment','readAttachmentImage','kbList','kbSearch','kbRead','createDocument']) {
    api[name]=async()=>{throw new Error(`Disabled in browser editor: ${name}`);};
  }
  window.desktop=api as unknown as DesktopApi;
  // Manual download only, never periodic browser downloads.
  localStorage.setItem('aidocs.autoSave',JSON.stringify({on:false,base:1}));
  localStorage.setItem('aidocs.showAi','0');
  const fileInput=document.querySelector<HTMLInputElement>('#browser-file')!;
  fileInput.addEventListener('change',async()=>{
    const file=fileInput.files?.[0];if(!file)return;
    try { if(confirmReplace()) emit('onOpenDocx',await importFile(file)); }
    catch(error){notify(String(error));}finally{fileInput.value='';}
  });
  const commands:Record<string,MenuCommand>={'browser-open':'open','browser-new':'new','browser-save':'save','browser-undo':'undo','browser-redo':'redo'};
  for(const [id,command] of Object.entries(commands))document.getElementById(id)!.addEventListener('click',()=>emit('onMenuCommand',command));
  // Browser keyboard shortcuts must not trigger Save Page / Open File dialogs.
  document.addEventListener('keydown',event=>{
    if(!(event.ctrlKey||event.metaKey))return;
    const command=event.key.toLowerCase()==='s'?(event.shiftKey?'save-as':'save'):event.key.toLowerCase()==='o'?'open':null;
    if(command){event.preventDefault();emit('onMenuCommand',command);}
  });
  window.addEventListener('beforeunload',event=>{emit('onCloseCheck');if(closeState.dirty)event.preventDefault();});
  window.addEventListener('pagehide',()=>{for(const url of handoffs)URL.revokeObjectURL(url);handoffs.clear();});
  return { api, emit };
}
