// Native ATOM must reproduce the qualified binary and every descriptive symbol.
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {assembleCurrent} from './support/editor-engine-harness.mjs';
const frozen=JSON.parse(await readFile('test/fixtures/editor-engine-milestone3.json','utf8'));
const artifact=await assembleCurrent();
assert.deepEqual(artifact.bytes,Uint8Array.from(Buffer.from(frozen.binaryBase64,'base64')));
assert.equal(artifact.sha256,frozen.sha256);
const current=new Map(Object.entries(artifact.symbols).map(([key,value])=>[key.toUpperCase(),value]));
for(const [key,value]of Object.entries(frozen.symbols))assert.equal(current.get(key.toUpperCase()),value,`symbol ${key}`);
const names=await readdir('src');assert.ok(names.every(n=>!n.endsWith('.asmi')));
for(const name of names.filter(n=>n.endsWith('.asm'))){
 const text=await readFile('src/'+name,'utf8');
 assert.ok(!/^\s*\.(include|routine|expectout|equ|db|dw|ds|org|end|binto)\b/im.test(text),`${name}: legacy directive`);
}
console.log(`Native ATOM source passed: ${artifact.bytes.length} identical bytes; ${Object.keys(frozen.symbols).length} unchanged symbol values; no source translation.`);
