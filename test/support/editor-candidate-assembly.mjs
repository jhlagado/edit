import {assembleNativeCandidateArtifacts,symbolsFromDebugMap} from "../../tools/atom-assembly.mjs";

export async function assembleEditorCandidate({name,source}) {
  const result=await assembleNativeCandidateArtifacts({sourcePath:source,base:0x100,entryAddress:0x100});
  return {bytes:result.bytes,name,symbols:symbolsFromDebugMap(result.debugMap)};
}
