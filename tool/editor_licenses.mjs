import {readFileSync,readdirSync,existsSync,writeFileSync} from 'node:fs';
import {resolve,join,sep} from 'node:path';
export function collectEditorLicenses(editor,destination){
 const lock=JSON.parse(readFileSync(join(editor,'package-lock.json'),'utf8'));const sections=[];
 for(const [relative,info]of Object.entries(lock.packages??{})){
  if(!relative||info.dev)continue;const dir=resolve(editor,relative);if(!dir.startsWith(resolve(editor,'node_modules')+sep)||!existsSync(dir))continue;
  const manifest=join(dir,'package.json');if(!existsSync(manifest))continue;const pkg=JSON.parse(readFileSync(manifest,'utf8'));const notices=readdirSync(dir,{withFileTypes:true}).filter(f=>f.isFile()&&/^(licen[cs]e|copying|notice)(\.|$)/i.test(f.name)).map(f=>`--- ${f.name} ---\n${readFileSync(join(dir,f.name),'utf8')}`).join('\n');
  if(notices)sections.push(`${pkg.name} ${pkg.version}\n${notices}`);
 }
 writeFileSync(destination,'Third-party dependencies installed for the offline GenOffice web editor.\n\n'+sections.join('\n\n==============================\n\n'));
}
