import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';
import os from 'node:os';

const args = process.argv.slice(2);
const arg = (key, fallback) => args.includes(key) ? args[args.indexOf(key)+1] : fallback;
const triptych = resolve(arg('--triptych', '/Users/johnhardy/projects/triptych'));
const artifactPath = resolve(arg('--artifact', '/Users/johnhardy/projects/edit/test/fixtures/editor-engine-milestone2.json'));
const output = resolve(arg('--output', 'work/host-qualification'));
const count = Number(arg('--samples', '30'));
assert.ok(Number.isInteger(count) && count >= 30 && count <= 60, '30–60 samples keep the fixed single-row typing oracle within 80 columns');
const port = Number(arg('--port', '4187'));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
await mkdir(output, {recursive:true});
const artifact = JSON.parse(await readFile(artifactPath, 'utf8'));
const binary = Buffer.from(artifact.binaryBase64, 'base64');
assert.equal(hash(binary), artifact.sha256);
const {installCpm22File, readCpm22File} = await import(pathToFileURL(join(triptych, 'tools/lib/cpm22-disk.mjs')));
let disk = new Uint8Array(await readFile(join(triptych, 'dist/wasm-browser/cpm22.img')));
disk = installCpm22File(disk, {name:'EDIT.COM', bytes:binary});
const pattern = Buffer.from('ordinary source line 0123456789\r\n');
const document = Uint8Array.from({length:16384}, (_,i) => pattern[i % pattern.length]);
disk = installCpm22File(disk, {name:'INPUT.TXT', bytes:document});
const extracted = readCpm22File(disk, 'EDIT.COM');
assert.deepEqual(Buffer.from(extracted.bytes ?? extracted).subarray(0,binary.length), binary);
const diskPath = join(output, 'private.img');
await writeFile(diskPath, disk);
await writeFile(join(output,'private-disk-provenance.json'),JSON.stringify({artifactPath,editorSha256:hash(binary),editorBytes:binary.length,diskSha256:hash(disk),documentBytes:document.length},null,2)+'\n');
if(args.includes('--prepare-only')) process.exit(0);
const require = createRequire(join(triptych, 'package.json'));
const {chromium} = require('@playwright/test');
const server = spawn(process.execPath, ['tools/serve-wasm-browser.mjs'], {cwd:triptych, env:{...process.env, PORT:String(port), TRIPTYCH_CPM22_IMAGE:diskPath}, stdio:['ignore','pipe','pipe']});
let serverLog = '';
server.stdout.on('data', b=>{serverLog += b;});
server.stderr.on('data', b=>{serverLog += b;});
let browser;
try {
  await new Promise((yes,no)=>{const timer=setTimeout(()=>no(new Error('server startup timeout: '+serverLog)),10000); server.stdout.on('data',()=>{if(serverLog.includes('Triptych WASM terminal:')){clearTimeout(timer);yes();}});server.on('exit',c=>{clearTimeout(timer);no(new Error('server exit '+c+serverLog));});});
  console.error(`Local server PID ${server.pid}, port ${port}; cleanup in finally`);
  browser = await chromium.launch({headless: !args.includes('--headed')});
  const context = await browser.newContext({viewport:{width:1280,height:900}});
  const page = await context.newPage();
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.waitForFunction(()=>document.querySelector('#terminal')?.textContent.trimEnd().endsWith('A>'));
  await page.locator('#terminal').focus();
  await page.keyboard.type('EDIT INPUT.TXT');
  await page.keyboard.press('Enter');
  await page.waitForFunction(()=>document.querySelector('#terminal')?.textContent.includes('^Q Quit'));
  await page.screenshot({path:join(output,'browser-before.png')});
  await page.evaluate(()=>{
    const terminal=document.querySelector('#terminal');
    window.hostSamples=[];
    window.armHostSample = () => {
      const previous={text:terminal.textContent,row:terminal.dataset.cursorRow,column:terminal.dataset.cursorColumn};
      window.hostSampleDone=false;
      const listener=e=>{
        const start=performance.now();
        const previousLines=previous.text.split('\n');
        const column=Number(previous.column)-1;
        const expectedFirstRow=(previousLines[0].slice(0,column)+e.key+previousLines[0].slice(column)).slice(0,80);
        const expectedColumn=String(Number(previous.column)+1);
        const observer=new MutationObserver(()=>{
          if(terminal.textContent.split('\n')[0]!==expectedFirstRow || terminal.dataset.cursorRow!=='1' || terminal.dataset.cursorColumn!==expectedColumn)return;
          const dom=performance.now(); observer.disconnect();
          const state={text:terminal.textContent,row:terminal.dataset.cursorRow,column:terminal.dataset.cursorColumn};
          requestAnimationFrame(()=>{window.hostSamples.push({key:e.key,startMs:start,domMs:dom-start,nextFrameMs:performance.now()-start,state});window.hostSampleDone=true;});
        });
        observer.observe(terminal,{subtree:true,childList:true,attributes:true});
      };
      terminal.addEventListener('keydown',listener,{capture:true,once:true});
    };
  });
  // First edit pays relocation; exclude it from the consecutive warm-key population.
  await page.evaluate(()=>window.armHostSample());
  await page.keyboard.press('x');
  await page.waitForFunction(()=>window.hostSampleDone);
  const cold = await page.evaluate(()=>window.hostSamples.pop());
  for(let i=0;i<count;i++){
    await page.evaluate(()=>window.armHostSample());
    await page.keyboard.press(String.fromCharCode(97+i%26));
    await page.waitForFunction(()=>window.hostSampleDone);
  }
  const samples=await page.evaluate(()=>window.hostSamples);
  await page.screenshot({path:join(output,'browser-after.png')});
  const summary = key => {const sorted=samples.map(x=>x[key]).sort((a,b)=>a-b);return {medianMs: sorted.length%2?sorted[(sorted.length-1)/2]:(sorted[sorted.length/2-1]+sorted[sorted.length/2])/2,p95Ms:sorted[Math.ceil(sorted.length*.95)-1]};};
  const report={format:'edit-host-qualification-v1',artifact:{path:artifactPath,sha256:artifact.sha256,bytes:binary.length},triptych:{root:triptych,head:execFileSync('git',['rev-parse','HEAD'],{cwd:triptych,encoding:'utf8'}).trim()},diskSha256:hash(disk),browser:{version:browser.version(),headless:!args.includes('--headed'),platform:process.platform,arch:process.arch},workload:'16KiB ordinary source; first edit then consecutive warm typing at start',boundaries:{start:'capturing real keyboard event on terminal',dom:'terminal text and cursor changed after real WASM serial output and DOM rendering',nextFrame:'following requestAnimationFrame opportunity; not verified physical display presentation'},cold,samples,summary:{dom:summary('domMs'),nextFrame:summary('nextFrameMs')}};
  report.machine={release:os.release(),cpu:os.cpus()[0]?.model,cpuCount:os.cpus().length,totalMemory:os.totalmem()};
  report.hostAssets={};
  for(const name of ['app.js','terminal.js','triptych_host_wasm_bg.wasm'])report.hostAssets[name]=hash(await readFile(join(triptych,'dist/wasm-browser',name)));
  await writeFile(join(output,'browser.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report.summary));
} finally {
  await browser?.close();
  server.kill('SIGTERM');
  await new Promise(r=>server.exitCode!==null?r():server.once('exit',r));
  await writeFile(join(output,'server.log'),serverLog);
  console.error('Local browser server stopped');
}
