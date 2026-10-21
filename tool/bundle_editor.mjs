import {cpSync,existsSync,mkdirSync,readdirSync,rmSync,writeFileSync,readFileSync} from 'node:fs';
import {resolve,dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const editor=join(root,'editor_web');
if(!process.argv.includes('--no-build')) {
 const result=spawnSync('npm',['run','build'],{cwd:editor,stdio:'inherit',shell:process.platform==='win32'});
 if(result.status!==0)process.exit(result.status??1);
}
const destination=join(root,'assets/editor');mkdirSync(destination,{recursive:true});
// Vite can retain mixed CRLF/LF from HTML inputs on Windows. Keep packaged
// entrypoints and their manifest hashes deterministic across host platforms.
for(const name of readdirSync(join(editor,'dist')).filter(name=>name.endsWith('.html'))) {
 const entry=join(editor,'dist',name);writeFileSync(entry,readFileSync(entry,'utf8').replace(/\r\n?/g,'\n'));
}
// assets/editor/assets is generated output owned solely by this bundler.
const generatedAssets=join(destination,'assets');
if(existsSync(generatedAssets))for(const name of readdirSync(generatedAssets)) {
 if(!existsSync(join(editor,'dist/assets',name)))rmSync(join(generatedAssets,name),{force:true});
}
cpSync(join(editor,'dist'),destination,{recursive:true});
for(const name of ['LICENSE','NOTICE','LICENSE-UNICODE.txt'])cpSync(join(editor,'vendor',name),join(destination,name));
const fonts=join(editor,'vendor/docs/renderer/fonts');
for(const name of readdirSync(fonts).filter(name=>/license|ofl|copyright/i.test(name)))cpSync(join(fonts,name),join(destination,`fonts-${name}`));
// UI fonts have their own notices too.
const uiFonts=join(editor,'vendor/ui/src/fonts');
if(existsSync(uiFonts))for(const name of readdirSync(uiFonts).filter(name=>/license|ofl|copyright/i.test(name)))cpSync(join(uiFonts,name),join(destination,`ui-fonts-${name}`));
const manifest={};
function visit(directory,prefix='') {for(const item of readdirSync(directory,{withFileTypes:true})){const key=prefix+item.name;if(item.isDirectory())visit(join(directory,item.name),key+'/');else manifest[key]=createHash('sha256').update(readFileSync(join(directory,item.name))).digest('hex');}}
visit(join(editor,'dist'));
writeFileSync(join(destination,'build-manifest.json'),JSON.stringify({upstream:'1cb2925afe173b266c1545a3871a397429e11b7e',files:manifest},null,2)+'\n');
console.log(`Packaged ${Object.keys(manifest).length} editor files into assets/editor`);
