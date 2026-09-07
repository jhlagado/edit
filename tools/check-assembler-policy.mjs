import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";

const forbidden = [
  ["translate", "AzmSourceToAtom"].join(""),
  ["project", "LegacyFixtureSyntaxToAtom"].join(""),
  ["@jhlagado", "azm"].join("/"),
  ["azm", "strict", "sidecar"].join("-"),
  ["compile", "Azm"].join(""),
];
const roots = ["package.json", "package-lock.json", "src", "test", "tools"];
const failures = [];

async function check(path) {
  const stat = await readdir(path, { withFileTypes: true }).catch(() => undefined);
  if (stat !== undefined) {
    for (const entry of stat) {
      if (entry.name === "node_modules" || entry.name === "dist") continue;
      await check(join(path, entry.name));
    }
    return;
  }
  if (/\.asmi$/i.test(path)) failures.push(`${path}: obsolete source-fragment extension`);
  const source = await readFile(path, "utf8").catch(() => undefined);
  if (source === undefined) return;
  for (const token of forbidden) {
    if (source.includes(token)) failures.push(`${path}: contains ${token}`);
  }
}

for (const root of roots) await check(root);
assert.deepEqual(failures, [], failures.join("\n"));
console.log("Assembler policy passed: ATOM is the only executable assembler.");
