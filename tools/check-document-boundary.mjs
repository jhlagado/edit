// A narrow source guard complements executed interface tests; it is not a Z80 verifier.
import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";

const ledger=JSON.parse(await readFile("src/editor-symbols.json","utf8"));
const semantic=new Map(Object.entries(ledger).map(([name,native])=>[native.toUpperCase(),name]));
const failures = [];
for (const file of await readdir("src")) {
  if (!/\.asm[i]?$/.test(file)) continue;
  const lines = (await readFile(`src/${file}`, "utf8")).split(/\r?\n/);
  lines.forEach((line, index) => {
    const code = line.replace(/;.*/, "").replace(/\b[A-Za-z_][A-Za-z0-9_]*\b/g,word=>semantic.get(word.toUpperCase())??word);
    const at = `src/${file}:${index + 1}`;
    if (file !== "editor-document.asm" && file !== "editor-memory.asm" && /\bEditorDocumentGap(?:Start|End)\b/.test(code)) {
      failures.push(`${at}: physical gap state outside document implementation`);
    }
    if (file !== "editor-document.asm" && file !== "editor-memory.asm") {
      if (/\bEditorText(?:Base|Limit)\b/.test(code)) failures.push(`${at}: physical text arena outside document implementation`);
      if (/\bLD\s+\(EditorLength\),/i.test(code)) failures.push(`${at}: document length write outside document implementation`);
    }
    if (file === "editor-document.asm" && /\bEditor(?:Cursor|Top|Status|Flags|Scratch[A-C]|Dma|Session\w*|CallBdos|Output\w*|Render\w*)\b/.test(code)) {
      failures.push(`${at}: document depends on session or adapter state`);
    }
    if (file === "editor-session.asm" && /\b(?:CALL|JP)\s+(?:[A-Z]+,)?\s*Editor(?:CallBdos|Output\w*|Render\w*|ReadByte|Save|LiteralInput|SearchBegin|ReplaceBegin)\b/i.test(code)) {
      failures.push(`${at}: semantic dispatcher calls an I/O adapter`);
    }
  });
}
assert.deepEqual(failures, [], failures.join("\n"));
console.log("Document ownership guard passed; execution tests check transitive I/O and state contracts.");
