// Incremental display is checked against the frozen full-rendering M2 binary.
// Counter gates concern warm editor work, not host or terminal wall latency.
import assert from 'node:assert/strict';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {assembleCurrent,loadBaseline,createEngineMachine,beginSession,executeCommands,
 executeRoutine,engineSnapshot,physicalFile,seedDocument,writeWord,readWord}
 from './support/editor-engine-harness.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const [current,reference]=await Promise.all([assembleCurrent(),loadBaseline(resolve(root,'test/fixtures/editor-engine-milestone2.json'))]);
assert.equal(typeof current.symbols.EditorPresent,'number','requires M3 presenter');
const bytes=t=>Uint8Array.from(Buffer.from(t,'ascii'));
const hl=v=>({h:v>>>8,l:v&255});
let commands=0,batches=0,warmSamples=0;
function same(pair,label){assert.deepEqual(engineSnapshot(pair[1]),engineSnapshot(pair[0]),label);}
function makePair(content,cursor=0){
 const pair=[reference,current].map(a=>{
  const m=createEngineMachine(a,{files:{'INPUT.NU':physicalFile(content)}});beginSession(m);
  if(cursor){writeWord(m.memory,m.symbol('EditorCursor'),cursor);executeRoutine(m,'EditorRender');}
  return m;
 });same(pair,'initial frame');return pair;
}
function command(pair,keys,label='command'){
 const start=pair[1].bdos.outputBytes.length;
 const screen=pair[1].bdos.terminal.snapshot();
 const result=pair.map(m=>executeCommands(m,keys));commands++;
 same(pair,`${label} ${JSON.stringify(keys)}`);
 return {metrics:result[1],output:pair[1].bdos.outputBytes.slice(start),screen};
}
// Trace only emitted characters/erase operations. CSI addressing and SGR do not
// count as row paint. The standalone adapter emits explicit absolute positions.
function paintedRows({output,screen}){
 const text=Buffer.from(output).toString('latin1'),rows=new Set();
 let row=screen.cursorRow,col=screen.cursorColumn;
 for(let i=0;i<text.length;){
  if(text.charCodeAt(i)===27){
   const match=/^\x1b\[([0-9;]*)([A-Za-z])/.exec(text.slice(i));assert.ok(match,'complete supported CSI');
   const params=match[1].split(';').map(Number),op=match[2];
   if(op==='H'||op==='f'){row=(params[0]||1)-1;col=(params[1]||1)-1;}
   else if(op==='K'){rows.add(row);}
   else if(op==='J'){for(let n=0;n<24;n++)rows.add(n);}
   else assert.equal(op,'m',`unexpected CSI ${op}`);
   i+=match[0].length;continue;
  }
  const c=text.charCodeAt(i++);
  if(c===13){col=0;continue;}if(c===10){row++;continue;}if(c===7)continue;
  assert.ok(c>=32&&c<127,'printable terminal payload');
  if(col>=80){row++;col=0;}rows.add(row);col++;
 }
 return [...rows].filter(r=>r<23).sort((a,b)=>a-b);
}
const right=[27,91,67],left=[27,91,68],up=[27,91,65],down=[27,91,66];
{
 const pair=makePair(bytes('abcdef\r\nsecond\nthird'));
 const move=command(pair,right,'cursor-only');
 assert.ok(move.metrics.terminalBytes<=20,'cursor-only bounded escape output');
 assert.deepEqual(paintedRows(move),[],'cursor-only must not paint text');
 const edit=command(pair,[88],'same-line insert');
 assert.deepEqual(paintedRows(edit),[0],'one changed text row');
 assert.ok(!Buffer.from(edit.output).toString('latin1').includes('\x1b[2J'),'same-line edit must not clear screen');
 const shrink=command(pair,[8],'same-line backspace');assert.deepEqual(paintedRows(shrink),[0]);
 for(const keys of [[6,65,66,27],[6,97,13],[18,90,27],[19],left,up,down,[127],[1]])command(pair,keys,'prompt/status/navigation');
}
// Down from a valid trailing empty line is still a boundary failure; a cached
// next boundary equal to EOF must not invent another empty line.
for(const text of ['', 'A\n', 'A\r\n']) {
 const pair=makePair(bytes(text),text.length);
 command(pair,down,'Down at terminal empty line');
}
// A known external screen owner may leave reverse video and arbitrary content.
// Forced recovery must restore a clean reference frame, not inherit its SGR.
{
 const pair=makePair(bytes('normal text\r\nsecond row'),3);
 for(const value of bytes('\x1b[7m\x1b[5;15HBROKEN\x1b[20;50H?'))pair[1].bdos.terminal.writeOutput(value);
 executeRoutine(pair[1],'EditorRender');same(pair,'external owner forced recovery');batches++;
}
// EOF/trailing-newline and top/bottom split/join damage, with full cell equality.
for(const text of ['', '\n', 'A\r\n', 'A\nB', Array.from({length:30},(_,i)=>`line${i}`).join('\r\n')]) {
 const content=bytes(text);
 for(const cursor of [0,content.length]){
  const pair=makePair(content,cursor);
  for(const keys of [[13],[88],[8],[8],right,[127],up,down])command(pair,keys,'split/join/EOF');
 }
}
{
 const text=Array.from({length:30},(_,i)=>`row${i}`).join('\n');
 const cursor=text.indexOf('row22')+3,pair=makePair(bytes(text),cursor);
 for(const keys of [[13],[8],[13],up,[127],down,[8]])command(pair,keys,'bottom-row');
}
// Prompts reuse renderer scratch and physical screen cursor fields. Cancellation
// must restore the document cursor and status without invalidating text pixels.
{
 const pair=makePair(bytes('abc\tabc\r\nother'),5);
 for(const keys of [[6,97,98,99,13],[18,88,89,27],right,[6,90,90,27],left,[6,90,90,13],[14],[19]])command(pair,keys,'prompt shared scratch');
 for(const m of pair)m.bdos.failures.set('write:INPUT.$$$',1);
 command(pair,[19],'save failure');command(pair,right,'after save failure');command(pair,[19],'save retry');
}
function splice(m,start,remove,input){
 const s=m.symbol;m.memory.set(input,s('EditorDma'));
 for(const [key,value]of Object.entries({Start:start,Remove:remove,Input:s('EditorDma'),Insert:input.length}))writeWord(m.memory,s(`EditorDocument${key}`),value);
 const r=executeRoutine(m,'EditorDocumentSplice');assert.equal(r.carry,false);
}
function presentPair(pair,label,force=false){
 executeRoutine(pair[0],'EditorRender');executeRoutine(pair[1],force?'EditorRender':'EditorPresent');
 same(pair,label);batches++;
}
{
 const pair=makePair(bytes('abcdefgh\r\nnext'));
 for(const m of pair){splice(m,2,1,bytes('XYZ'));splice(m,5,1,bytes('Q'));}
 presentPair(pair,'two direct splices before Present');
 // Saturation must survive intervening semantic movement and rejected edits.
 for(const m of pair){
  splice(m,1,0,bytes('1'));splice(m,1,0,bytes('2'));splice(m,1,0,bytes('3'));
  executeRoutine(m,'EditorSessionExecute',{registers:{a:m.symbol('EditorOpRight')}});
 }
 presentPair(pair,'batched changes survive semantic read');
 // Same length, unrelated content must not reuse boundaries or line anchors.
 const replacement=new Uint8Array(readWord(pair[0].memory,pair[0].symbol('EditorLength'))).fill(122);
 for(const m of pair){
  executeRoutine(m,'EditorDocumentReset');
  for(const a of replacement)assert.equal(executeRoutine(m,'EditorDocumentAppend',{registers:{a}}).carry,false);
  writeWord(m.memory,m.symbol('EditorCursor'),0);writeWord(m.memory,m.symbol('EditorTop'),0);
 }
 presentPair(pair,'Reset/Append reload');
 for(const m of pair)seedDocument(m,new Uint8Array(replacement.length).fill(113),{gapAt:3});
 presentPair(pair,'same-length direct fixture invalidation');
 for(const m of pair)executeRoutine(m,'EditorBufferInsertByte',{registers:{a:88}});
 presentPair(pair,'legacy direct buffer mutation');
 presentPair(pair,'forced repaint after valid cached frame',true);
}
// Warm ordinary source and long-line work: compare length-scaled fixtures while
// keeping edit geometry equivalent. Once established, fixed-width paints must
// not inspect an unchanged long prefix or suffix again on each key.
function warmCase(content,cursor,label,limit){
 const pair=makePair(content,cursor);command(pair,[120],`${label} cold`);
 const samples=[];
 for(let i=0;i<4;i++){
  const r=command(pair,[97+i],`${label} warm`);samples.push(r.metrics.textScalarReadBytes);warmSamples++;
  assert.ok(r.metrics.textScalarReadBytes<=limit,`${label}: warm scan ${r.metrics.textScalarReadBytes} exceeds bounded ${limit}`);
 }
 return samples;
}
for(const [name,value]of [['printable',65],['tabs',9]]){
 const short=warmCase(new Uint8Array(2048).fill(value),1024,`${name} 2K`,900);
 const long=warmCase(new Uint8Array(16384).fill(value),8192,`${name} 16K`,900);
 assert.ok(Math.max(...long)<=Math.max(...short)+128,`${name}: warm reads grow with unchanged prefix`);
}
for(const width of [200,1600]){
 const row='A'.repeat(width),text=Array.from({length:23},()=>row).join('\n');
 warmCase(bytes(text),11*(width+1)+(width>>>1),`23 long rows width${width}`,5000);
}
// Deterministic mixed commands originally exposed the cached trailing-EOF
// regression after 423 matching steps. Retain that prefix and extend to 1000.
// Every command is compared, so a later redraw cannot hide a stale frame.
let mixedSeed=0x127ab,mixedCommands=0;
const random=n=>{mixedSeed=(Math.imul(mixedSeed,1664525)+1013904223)>>>0;return mixedSeed%n;};
const mixedKeys=[[65],[9],[13],[8],[127],up,down,right,left,[19],[6,90,27]];
for(const [round,count]of [150,150,150,184,183,183].entries()) {
 const text=bytes(Array.from({length:35},(_,i)=>'x'.repeat((i*17)%140)+(i%3?'\tZZ\t':'')+'y'.repeat(i%11)).join('\r\n'));
 const mode=round%3,cursor=mode===0?0:mode===1?Buffer.from(text).indexOf('ZZ'):text.length;
 const pair=makePair(text,cursor);
 for(let index=0;index<count;index++){
  const keys=mixedKeys[random(mixedKeys.length)];
  command(pair,keys,`mixed round${round} step${index} seed${mixedSeed}`);mixedCommands++;
 }
}
console.log(JSON.stringify({result:'pass',commands,batches,warmSamples,mixedCommands,artifactBytes:current.bytes.length},null,2));
