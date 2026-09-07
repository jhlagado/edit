import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {dirname,resolve} from 'node:path';
import {assembleAtomProject,materializeAtomGeneration,renderAtomArtifacts} from 'atom-z80';

export const projectOwnedCandidates=Object.freeze([{name:'editor.asm'}]);

export function symbolsFromDebugMap(debugMap){
 return Object.fromEntries(debugMap.symbols.flatMap(s=>{const value=s.address??s.value;return value===undefined?[]:[[s.name,value]];}));
}

// This ledger restores descriptive API names in debug/test metadata only.
// Native source and machine code never pass through a symbol rewriter.
function descriptiveDebugMap(debugMap,ledger){
 const reverse=new Map(Object.entries(ledger).map(([name,native])=>[native.toUpperCase(),name]));
 assert.equal(reverse.size,Object.keys(ledger).length,'native symbol ledger must be one-to-one');
 const restore=s=>{const name=reverse.get(s.name.toUpperCase());if(!name)return s;
  const identity=s.identity?.endsWith(`:${s.name}`)?s.identity.slice(0,-s.name.length)+name:s.identity;
  return {...s,name,...(identity===undefined?{}:{identity})};};
 return {...debugMap,symbols:debugMap.symbols.map(restore),files:Object.fromEntries(Object.entries(debugMap.files).map(([key,file])=>[key,{...file,...(file.symbols?{symbols:file.symbols.map(restore)}:{})}]))};
}

async function assembleNative({sourcePath,ledgerPath,base=0x100,entryAddress=base,expectedBytes}){
 const result=await assembleAtomProject({root:dirname(sourcePath),entry:sourcePath.split('/').at(-1),
  target:{start:0,capacity:0xffff},maxInstructions:50_000_000,maxCycles:500_000_000});
 const bytes=materializeAtomGeneration(result.generation,{base}).bytes;
 if(expectedBytes!==undefined)assert.deepEqual(bytes,Uint8Array.from(expectedBytes),'native ATOM binary differs from frozen artifact');
 const ledger=JSON.parse(await readFile(ledgerPath,'utf8'));
 const artifacts=renderAtomArtifacts(result,{base,entryAddress});
 return {bytes,debugMap:descriptiveDebugMap(artifacts.d8,ledger)};
}

export async function assembleProjectOwnedAtomArtifacts({outputDirectory,candidate,expectedBytes,base=0x100,entryAddress=base}){
 const name=typeof candidate==='string'?candidate:candidate.name;
 return assembleNative({sourcePath:resolve(outputDirectory,name),ledgerPath:resolve(outputDirectory,'editor-symbols.json'),expectedBytes,base,entryAddress});
}

export async function assembleNativeCandidateArtifacts({sourcePath,base=0x100,entryAddress=base,expectedBytes}){
 sourcePath=resolve(sourcePath);
 return assembleNative({sourcePath,ledgerPath:sourcePath+'.symbols.json',base,entryAddress,expectedBytes});
}
