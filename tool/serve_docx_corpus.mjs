// Local-only fixture server for integration_test/factory_docx_test.dart.
// Source documents are read-only; edited copies go to a separate results folder.
import http from 'node:http';
import { createHash } from 'node:crypto';
import { mkdtempSync, readdirSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const argument = name => {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
};
const source = argument('--source-dir');
if (!source) throw new Error('Usage: node tool/serve_docx_corpus.mjs --source-dir <folder> [--results-dir <folder>] [--port 8943]');
const sourceDirectory = resolve(source);
const resultsDirectory = resolve(argument('--results-dir') || mkdtempSync(join(tmpdir(), 'genoffice-docx-qa-')));
if (sourceDirectory.toLowerCase() === resultsDirectory.toLowerCase()) throw new Error('Results must use a separate folder.');
const port = Number(argument('--port') || 8943);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid port.');
const files = readdirSync(sourceDirectory, { withFileTypes: true })
  .filter(file => file.isFile() && !file.name.startsWith('~$') && /\.docx$/i.test(file.name))
  .map(file => ({ name: file.name, bytes: readFileSync(join(sourceDirectory, file.name)) }))
  .sort((a, b) => a.name.localeCompare(b.name));
if (files.length === 0) throw new Error('No DOCX files found.');
if (files.some(file => file.bytes.length > 20 * 1024 * 1024)) throw new Error('Corpus imports must be at most 20 MB each.');
mkdirSync(resultsDirectory, { recursive: true });
writeFileSync(join(resultsDirectory, 'manifest.json'), JSON.stringify(files.map(file => ({ name: file.name, sha256: createHash('sha256').update(file.bytes).digest('hex') })), null, 2));

http.createServer((request, response) => {
  if (request.method === 'GET' && request.url === '/manifest') {
    response.setHeader('Content-Type', 'application/json');
    return response.end(JSON.stringify(files.map(({ name }) => ({ name }))));
  }
  const match = /^\/(files|results)\/(\d+)$/.exec(request.url || '');
  const index = match ? Number(match[2]) : -1;
  if (!match || !files[index]) { response.writeHead(404); return response.end(); }
  if (request.method === 'GET' && match[1] === 'files') {
    response.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    return response.end(files[index].bytes);
  }
  if (request.method === 'POST' && match[1] === 'results') {
    let size = 0; const chunks = [];
    request.on('data', chunk => {
      size += chunk.length;
      if (size > 32 * 1024 * 1024) request.destroy(); else chunks.push(chunk);
    });
    request.on('end', () => {
      writeFileSync(join(resultsDirectory, `${index}.docx`), Buffer.concat(chunks));
      console.log(`Saved QA result ${index + 1}/${files.length}`);
      response.end('ok');
    });
    return;
  }
  response.writeHead(405); response.end();
}).listen(port, '127.0.0.1', () => console.log(`Serving ${files.length} private DOCX files on 127.0.0.1:${port}; results: ${resultsDirectory}`));
