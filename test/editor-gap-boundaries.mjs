// M2 physical-gap proofs. Fixtures may place a gap inside CRLF; public editing
// endpoints remain logical-character boundaries. This is not a latency test.
import assert from 'node:assert/strict';
import {assembleCurrent, createEngineMachine, seedDocument, logicalDocument,
  beginSession, executeRoutine, executeCommands, readWord, writeWord, physicalFile}
  from './support/editor-engine-harness.mjs';
const artifact = await assembleCurrent();
const s = artifact.symbols;
assert.equal(typeof s.EditorDocumentGapStart, 'number', 'requires M2 gap implementation');
const capacity = s.EditorTextLimit - s.EditorTextBase;
const bytes = text => Uint8Array.from(Buffer.from(text, 'ascii'));
const regs = (value, hi, lo) => ({[hi]:value >>> 8, [lo]:value & 255});
const hl = v => regs(v,'h','l'), de = v => regs(v,'d','e'), bc = v => regs(v,'b','c');
const gap = m => [readWord(m.memory,s.EditorDocumentGapStart),readWord(m.memory,s.EditorDocumentGapEnd)];
const physical = m => ({gap:gap(m), length:readWord(m.memory,s.EditorLength),
  arena:m.memory.slice(s.EditorTextBase,s.EditorTextLimit)});
let reads=0, splices=0, saves=0;
function fresh(content, at) {const m=createEngineMachine(artifact); seedDocument(m,content,{gapAt:at}); return m;}
function invoke(m,name,registers={}) {return executeRoutine(m,name,{registers});}
function request(m,start,remove,input) {
  m.memory.set(input,s.EditorDma);
  for(const [name,value] of Object.entries({Start:start,Remove:remove,Input:s.EditorDma,Insert:input.length}))
    writeWord(m.memory,s[`EditorDocument${name}`],value);
}
function splice(m,start,remove,input) {request(m,start,remove,input);splices++;return invoke(m,'EditorDocumentSplice');}
function unchanged(m,before,label) {assert.deepEqual(physical(m),before,label);}
const content=bytes('A\r\nBC\tD\n');
// Every physical gap position, including between CR and LF, with byte and span
// reads at every logical offset. Reconstruct spans independently from memory.
for(let at=0;at<=content.length;at++) {
  const m=fresh(content,at), before=physical(m);
  for(let offset=0;offset<=content.length+1;offset++) {
    let r=invoke(m,'EditorDocumentReadByte',hl(offset));reads++;
    assert.equal(r.carry,offset>=content.length);
    if(!r.carry)assert.equal(r.a,content[offset]);
    r=invoke(m,'EditorDocumentReadSpan',hl(offset));reads++;
    let n=(m.runtime.cpu.b<<8)|m.runtime.cpu.c;
    assert.equal(r.carry,offset>=content.length);
    if(!r.carry){assert.ok(n>0&&n<=content.length-offset);assert.deepEqual(m.memory.slice(r.hl,r.hl+n),content.slice(offset,offset+n));}
    else assert.equal(n,0);
    r=invoke(m,'EditorDocumentReadSpanBackward',hl(offset));reads++;
    n=(m.runtime.cpu.b<<8)|m.runtime.cpu.c;
    assert.equal(r.carry,offset===0||offset>content.length);
    if(!r.carry){assert.ok(n>0&&n<=offset);assert.deepEqual(m.memory.slice(r.hl-n+1,r.hl+1),content.slice(offset-n,offset));}
    else assert.equal(n,0);
    for(const query of ['BC','C\tD','D','ZX']) {
      const q=bytes(query);m.memory.set(q,s.EditorQueryBuffer);
      r=invoke(m,'EditorDocumentMatchLiteral',{...hl(offset),...de(s.EditorQueryBuffer),c:q.length});reads++;
      assert.equal(m.runtime.cpu.flags.Z!==0,Buffer.from(content.slice(offset,offset+q.length)).equals(Buffer.from(q)));
    }
  }
  // Every source subrange, including reads whose physical spans cross the gap.
  for(let start=0;start<=content.length;start++)for(let end=start;end<=content.length;end++) {
    m.memory.fill(0x91,s.EditorDma,s.EditorDma+32);
    const r=invoke(m,'EditorDocumentReadRange',{...hl(start),...de(s.EditorDma+1),...bc(end-start)});reads++;
    assert.equal(r.carry,false);assert.deepEqual(m.memory.slice(s.EditorDma+1,s.EditorDma+1+end-start),content.slice(start,end));
    assert.equal(m.memory[s.EditorDma],0x91);assert.equal(m.memory[s.EditorDma+1+end-start],0x91);
  }
  unchanged(m,before,'reads must not relocate or rewrite the arena');
}
// Exhaustive small legal and illegal endpoints, independent byte-splice oracle.
// Include no-op and identical edits; rejected/no-op calls preserve unused bytes.
for(let at=0;at<=content.length;at++)for(let start=0;start<=content.length;start++)for(let end=start;end<=content.length;end++)
for(const insertion of ['', 'X', '\r\n', '\t']) {
  const m=fresh(content,at), before=physical(m), input=bytes(insertion);
  const r=splice(m,start,end-start,input);
  const illegal=content[start-1]===13||content[end-1]===13;
  assert.equal(r.carry,illegal,`gap${at} splice${start}:${end} ${JSON.stringify(insertion)}`);
  if(illegal){assert.equal(r.a,s.EditorDocumentErrorText);unchanged(m,before,'bad CRLF endpoint');}
  else {
    assert.deepEqual(logicalDocument(m),Uint8Array.from([...content.slice(0,start),...input,...content.slice(end)]));
    if(start===end&&!input.length)unchanged(m,before,'empty splice');
    assert.equal(m.memory[s.EditorDocChangeFlags],start===end&&!input.length?0:1|((insertion.includes('\n')||content.slice(start,end).includes(10))?2:0));
  }
}
// Invalid insertion encoding must be rejected before a distant gap move.
for(let at=0;at<=content.length;at++)for(const input of [bytes('\r'),bytes('\rX'),Uint8Array.of(0)]) {
 const m=fresh(content,at),before=physical(m);
 const result=splice(m,0,0,input);assert.equal(result.carry,true);assert.equal(result.a,s.EditorDocumentErrorText);
 unchanged(m,before,'invalid text must not relocate gap');
}
// Small nonzero gaps force overlapping block transfers in both directions.
// Patterned content detects wrong copy direction, unlike repeated-byte fixtures.
for(const size of [1,2,7]) {
 const nearFull=Uint8Array.from({length:capacity-size},(_,i)=>65+i%26);
 for(const at of [0,20000,nearFull.length])for(const destination of [0,nearFull.length]) {
  const m=fresh(nearFull,at);
  assert.equal(splice(m,destination,0,bytes('!')).carry,false);
  assert.deepEqual(logicalDocument(m),Uint8Array.from([...nearFull.slice(0,destination),33,...nearFull.slice(destination)]));
 }
}
// Checked ranges and external aliases fail before relocating a non-end gap.
for(const patch of [
 {Start:content.length+1}, {Start:1,Remove:65535},
 {Input:s.EditorTextBase,Insert:1},
 {Input:s.EditorDocumentGapStart,Insert:1}, {Input:s.EditorDocumentGapEnd,Insert:2},
 {Input:65535,Insert:2},
]) {
 const m=fresh(content,4),before=physical(m);request(m,0,0,bytes('X'));
 for(const [name,value] of Object.entries(patch))writeWord(m.memory,s[`EditorDocument${name}`],value);
 const r=invoke(m,'EditorDocumentSplice');splices++;assert.equal(r.carry,true);
 assert.equal(r.a,('Input' in patch&&patch.Input!==65535)?s.EditorDocumentErrorAlias:s.EditorDocumentErrorRange);
 unchanged(m,before,'range/alias rejection must not relocate');
}
// Capacity rejection, zero-sized/full-sized gaps, and full-buffer replacement.
for(const at of [0,1,20000,capacity]) {
  const full=new Uint8Array(capacity).fill(65),m=fresh(full,at), before=physical(m);
  assert.equal(splice(m,20000,0,bytes('X')).carry,true);unchanged(m,before,'full rejection');
  assert.equal(splice(m,20000,0,bytes('')).carry,false);unchanged(m,before,'zero-gap no-op');
  assert.equal(splice(m,20000,1,bytes('B')).carry,false);full[20000]=66;assert.deepEqual(logicalDocument(m),full);
  assert.equal(splice(m,19999,2,bytes('')).carry,false);assert.equal(logicalDocument(m).length,capacity-2);
  assert.equal(splice(m,0,0,bytes('YZ')).carry,false);assert.deepEqual(logicalDocument(m),Uint8Array.from([89,90,...full.slice(0,19999),...full.slice(20001)]));
}
{
 const m=fresh(new Uint8Array(),0),before=physical(m);
 assert.equal(splice(m,0,0,bytes('')).carry,false);unchanged(m,before,'whole-arena gap no-op');
 assert.equal(splice(m,0,0,bytes('A\r\nB')).carry,false);assert.deepEqual(logicalDocument(m),bytes('A\r\nB'));
}
function session(content,at) {
 const m=createEngineMachine(artifact,{files:{'INPUT.NU':physicalFile(content)}});
 beginSession(m);seedDocument(m,content,{gapAt:at});return m;
}
// Actual save path for every offset within a 128-byte record, with a partial
// final record. Gap at0/128 is also a direct-record boundary; 1..127 cross it.
const diskText=Uint8Array.from({length:301},(_,i)=>65+i%26);
for(let at=0;at<128;at++) {
 const m=session(diskText,at),before=physical(m);
 const r=invoke(m,'EditorSave');saves++;assert.equal(r.carry,false);
 assert.deepEqual(m.bdos.files.get('INPUT.NU'),physicalFile(diskText));unchanged(m,before,'save must not flatten');
}
// Failed writes, close, and both installation renames preserve source, document
// and gap; the next actual Save retries successfully without reseeding.
for(const at of [1,127,128,255,301])for(const event of ['write:INPUT.$$$','close:INPUT.$$$','rename:INPUT.NU->INPUT.BAK','rename:INPUT.$$$->INPUT.NU']) {
 const original=bytes('ORIGINAL\r\n');const m=session(original,original.length);
 seedDocument(m,diskText,{gapAt:at});m.memory[s.EditorFlags]|=s.EditorFlagDirty;
 const before=physical(m);m.bdos.failures.set(event,1);
 const r=invoke(m,'EditorSave');saves++;assert.equal(r.carry,true,event);
 unchanged(m,before,event);assert.deepEqual(m.bdos.files.get('INPUT.NU'),physicalFile(original),event);
 assert.equal(invoke(m,'EditorSave').carry,false,`${event} retry`);saves++;
 unchanged(m,before,`${event} retry`);assert.deepEqual(m.bdos.files.get('INPUT.NU'),physicalFile(diskText));
}
// Failed installation plus failed rollback preserves the old bytes as BAK;
// retry remains blocked by that backup until explicit external recovery.
{
 const original=bytes('ORIGINAL\r\n'),m=session(original,original.length);
 seedDocument(m,diskText,{gapAt:127});m.memory[s.EditorFlags]|=s.EditorFlagDirty;
 const before=physical(m);
 m.bdos.failures.set('rename:INPUT.$$$->INPUT.NU',1);
 m.bdos.failures.set('rename:INPUT.BAK->INPUT.NU',1);
 assert.equal(invoke(m,'EditorSave').carry,true);saves++;
 assert.equal(m.memory[s.EditorStatus],s.EditorStatusSaveRollback);
 assert.equal(m.bdos.files.has('INPUT.NU'),false);
 assert.equal(m.bdos.files.has('INPUT.$$$'),false);
 assert.deepEqual(m.bdos.files.get('INPUT.BAK'),physicalFile(original));unchanged(m,before,'rollback failure');
 assert.equal(invoke(m,'EditorSave').carry,true);saves++;
 assert.equal(m.memory[s.EditorStatus],s.EditorStatusSaveConflict);
 unchanged(m,before,'backup collision on retry');
 // Explicit test-fixture recovery models the user restoring the retained BAK;
 // it is deliberately not attributed to editor recovery or measured as a save.
 m.bdos.files.set('INPUT.NU',m.bdos.files.get('INPUT.BAK'));m.bdos.files.delete('INPUT.BAK');
 assert.equal(invoke(m,'EditorSave').carry,false);saves++;
 assert.deepEqual(m.bdos.files.get('INPUT.NU'),physicalFile(diskText));unchanged(m,before,'recovered retry');
}
// First save of a new file and both clean/confirmed-discard exits retain the
// actual entry caller stack with a gap that is not at the document end.
for(const saveFirst of [false,true]) {
 const m=createEngineMachine(artifact);beginSession(m,'NEW.NU');
 seedDocument(m,content,{gapAt:2});const before=physical(m);
 if(saveFirst){executeCommands(m,[19]);saves++;assert.deepEqual(m.bdos.files.get('NEW.NU'),physicalFile(content));unchanged(m,before,'new first save');}
 const r=executeCommands(m,saveFirst?[17]:[17,17]);
 assert.equal(r.returnPc,0x40);assert.equal(r.finalSp,0xe900);unchanged(m,before,'exit');
 if(!saveFirst)assert.equal(m.bdos.files.has('NEW.NU'),false);
}
// Real navigation, query prompt/search, rendering and Save do not drag the gap.
for(let at=0;at<=content.length;at++) {
 const m=session(content,at),before=physical(m);
 for(const keys of [[27,91,67],[27,91,66],[27,91,65],[27,91,68],[6,66,67,13],[14],[19]]) {
  executeCommands(m,keys);unchanged(m,before,'read-only command relocated gap');
 }
}
console.log(JSON.stringify({result:'pass',physicalGapPositions:content.length+1,reads,splices,saves,capacity},null,2));
