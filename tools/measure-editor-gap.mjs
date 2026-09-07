// M2 gap workload ruler: full commands, read-only invariants, and both frozen baselines.
import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { assembleCurrent, loadBaseline, memoryAccounts, createEngineMachine,
  beginSession, executeCommands, executeRoutine, engineSnapshot, snapshotDigest,
  physicalFile, writeWord, readWord, seedDocument, logicalDocument, sha256,
} from "../test/support/editor-engine-harness.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const option = name => { const index = args.indexOf(name); return index < 0 ? undefined : args[index + 1]; };
const only = option("--only"), output = option("--output");
const artifacts = {
  original: await loadBaseline(),
  milestone1: await loadBaseline(resolve(root, "test/fixtures/editor-engine-milestone1.json")),
  current: await assembleCurrent(root),
};
assert.equal(typeof artifacts.current.symbols.EditorDocumentGapStart, "number", "current candidate has no gap representation");
assert.equal(typeof artifacts.current.symbols.EditorDocumentGapEnd, "number", "current candidate has no gap representation");
const lock = JSON.parse(await readFile(resolve(root, "package-lock.json"), "utf8"));
const columns = ["instructions", "tStates", "textReadBytes", "textCopyReadBytes", "textScalarReadBytes", "textWriteBytes", "terminalBytes", "recordsRead", "recordsWritten", "stackDepthFromPrivateTop"];
const pattern = Buffer.from("proc main()\n  let value = 42; // ordinary source text\nend\n", "ascii");
const source = length => Uint8Array.from({ length }, (_, i) => pattern[i % pattern.length]);
const search = text => [6, ...Buffer.from(text), 13];
function gap(machine) {
  if (machine.artifact.symbols.EditorDocumentGapStart === undefined) return null;
  return { start: readWord(machine.memory, machine.symbol("EditorDocumentGapStart")),
    end: readWord(machine.memory, machine.symbol("EditorDocumentGapEnd")) };
}
function observable(machine) { return snapshotDigest(engineSnapshot(machine)); }
function observe(machine, name, run, { readOnly = false, noTailCopy = false } = {}) {
  const before = gap(machine);
  const metrics = run();
  const after = gap(machine);
  if (readOnly) {
    assert.deepEqual(after, before, `${name}: read-only operation relocated gap`);
    assert.equal(metrics.textWriteBytes, 0, `${name}: read-only operation wrote arena`);
  }
  if (noTailCopy && after !== null) assert.equal(metrics.textCopyReadBytes, 0, `${name}: warm typing copied text`);
  return { name, metrics, gapBefore: before, gapAfter: after, observable: observable(machine) };
}
function command(machine, name, bytes, checks) {
  return observe(machine, name, () => executeCommands(machine, bytes), checks);
}
function prepare(artifact, workload) {
  const machine = createEngineMachine(artifact, { files: { "INPUT.NU": physicalFile(workload.text) } });
  const entry = beginSession(machine);
  const initialGap = gap(machine);
  if (initialGap !== null) assert.deepEqual(initialGap, { start: workload.text.length, end: artifact.symbols.EditorTextCapacity }, "load must leave an end gap");
  if (workload.gapAt !== undefined) seedDocument(machine, workload.text, { gapAt: workload.gapAt });
  assert.deepEqual(Array.from(logicalDocument(machine)), Array.from(workload.text));
  writeWord(machine.memory, machine.symbol("EditorCursor"), workload.cursor ?? 0);
  const layout = observe(machine, "fixture-layout (setup excluded)", () => executeRoutine(machine, "EditorRender"), { readOnly: true });
  return { machine, setup: { entry, initialGap, seededGap: workload.gapAt ?? null, layout } };
}
function warm(machine, count) {
  const samples = [], hashes = [];
  const totals = Object.fromEntries(columns.map(k => [k, 0]));
  const bdosCalls = {};
  const before = gap(machine);
  for (let index = 0; index < count; index++) {
    const sample = command(machine, `warm-key-${index + 1}`, [97 + (index % 26)], { noTailCopy: true });
    samples.push(columns.map(k => sample.metrics[k]));
    hashes.push(sha256(Buffer.from(JSON.stringify(sample.observable))));
    for (const k of columns) {
      if (k === "stackDepthFromPrivateTop") totals[k] = Math.max(totals[k], sample.metrics[k]);
      else totals[k] += sample.metrics[k];
    }
    for (const [k,v] of Object.entries(sample.metrics.bdosCalls)) bdosCalls[k] = (bdosCalls[k] ?? 0) + v;
  }
  return { name: `warm-${count}-keys`, metrics: { ...totals, bdosCalls, boundary: "Sum of consecutive complete MainLoop-to-MainLoop commands; maximum stack depth" },
    sampleColumns: columns, samples, perKeyObservableSha256: hashes,
    gapBefore: before, gapAfter: gap(machine), observable: observable(machine) };
}

const workloads = [];
for (const size of [16384, 40960, 46848]) for (const position of ["beginning", "middle", "end"]) {
  workloads.push({ name: `cold-and-warm100-${size}-${position}`, text: source(size),
    cursor: position === "beginning" ? 0 : position === "middle" ? size >>> 1 : size,
    kind: "typing", description: "Loaded end gap; cold first insertion at fixture cursor, then100 consecutive complete typing commands. 46848 leaves256 free bytes." });
}
workloads.push({ name: "distant-search-then-first-edit-16384", text: Buffer.concat([Buffer.from("ORIGIN\n"), Buffer.from(source(16370)), Buffer.from("\nTARGET")]),
  kind: "far", description: "Establish gap at beginning with an insertion, search far without relocation, then separately count first distant edit and100 warm keys." });
workloads.push({ name: "read-layout-search-16384", text: Buffer.concat([Buffer.from(source(8189)), Buffer.from("\nNEEDLE\n"), Buffer.from(source(8187))]),
  gapAt: 8192, kind: "reads", description: "Seed gap inside NEEDLE; cursor movement, complete find and full render must preserve physical gap and write no arena bytes." });
for (const gapAt of [8191, 8192, 8193]) workloads.push({ name: `save-cross-gap-${gapAt}`, text: source(16391), gapAt, kind: "save",
  description: "Complete save with a seeded middle gap adjacent to or on a128-byte boundary and a final partial record; gap must not move." });
for (const [label, byte, size] of [["printable", 120, 16384], ["tabs", 9, 8193]]) workloads.push({ name: `long-${label}-cold-warm8`, text: new Uint8Array(size).fill(byte),
  cursor: size >>> 1, kind: "long", description: "Cold middle edit plus eight warm complete commands on a long line; full layout/render remains included." });

function measure(artifact, workload) {
  const { machine, setup } = prepare(artifact, workload);
  const stages = [];
  if (workload.kind === "typing" || workload.kind === "long") {
    stages.push(command(machine, "cold-first-edit", [120]));
    stages.push(warm(machine, workload.kind === "typing" ? 100 : 8));
  } else if (workload.kind === "far") {
    stages.push(command(machine, "establish-gap-at-beginning", [120]));
    stages.push(command(machine, "far-search-without-relocation", search("TARGET"), { readOnly: true }));
    stages.push(command(machine, "first-edit-after-far-search", [121]));
    stages.push(warm(machine, 100));
  } else if (workload.kind === "reads") {
    stages.push(command(machine, "move-right-left-without-relocation", [27,91,67,27,91,68], { readOnly: true }));
    stages.push(command(machine, "find-across-gap-without-relocation", search("NEEDLE"), { readOnly: true }));
    assert.equal(readWord(machine.memory, machine.symbol("EditorCursor")), 8190);
    stages.push(observe(machine, "full-render-without-relocation", () => executeRoutine(machine, "EditorRender"), { readOnly: true }));
  } else if (workload.kind === "save") {
    stages.push(command(machine, "save-without-relocation", [19], { readOnly: true }));
    assert.deepEqual(machine.bdos.files.get("INPUT.NU"), physicalFile(workload.text));
  }
  return { setup, stages };
}
const selected = workloads.filter(w => !only || w.name.includes(only));
assert.ok(selected.length, "no matching workload");
const result = { format: "edit-engine-gap-measurements-v1",
  comparisonLabels: { original: "original frozen editor", milestone1: "completed M1 contiguous editor", current: "current gap candidate" },
  runtime: { node: process.version, pin: lock.packages["node_modules/@jhlagado/debug80-runtime"].resolved,
    runtimeSourceSha256: sha256(await readFile(resolve(root, "node_modules/@jhlagado/debug80-runtime/dist/z80/runtime.js"))),
    cpuSourceSha256: sha256(await readFile(resolve(root, "node_modules/@jhlagado/debug80-runtime/dist/z80/cpu.js"))) },
  accounting: { cpu: "Editor-side Z80 instructions/T-states; fake BDOS cycles excluded.",
    copies: "LDI/LDD/LDIR/LDDR source reads inside text arena; may include save-record packing. Other text reads are scalar/scan activity.",
    setup: "Entry, initial gap seeding, cursor placement and fixture layout outside command measurement; setup costs separately recorded.",
    warm: "Raw per-key columns retained; sums include all100 redraws; stack field is maximum, not sum.",
    invariance: "Read-only operations assert unchanged gap bounds AND zero arena writes; save can copy text to DMA without relocating gap.",
    equivalence: "Logical state/screen/file digests compared at each stage and every warm key against both frozen artifacts.",
    hostLatency: "Not measured; no keystroke wall latency inferred." },
  artifacts: Object.fromEntries(Object.entries(artifacts).map(([name,a]) => [name, { sha256: a.sha256, provenance: a.provenance, accounts: memoryAccounts(a) }])), workloads: [] };
for (const w of selected) {
  process.stderr.write(`Measuring gap workload ${w.name}\n`);
  const row = { name: w.name, description: w.description,
    input: { bytes: w.text.length, sha256: sha256(w.text), cursor: w.cursor ?? 0, gapAt: w.gapAt ?? null },
    results: Object.fromEntries(Object.entries(artifacts).map(([name,a]) => [name, measure(a,w)])) };
  for (const name of ["original", "milestone1"]) {
    for (let i = 0; i < row.results.current.stages.length; i++) {
      assert.deepEqual(row.results.current.stages[i].observable, row.results[name].stages[i].observable, `${w.name}/${i}: differs from ${name}`);
      assert.deepEqual(row.results.current.stages[i].perKeyObservableSha256, row.results[name].stages[i].perKeyObservableSha256, `${w.name}/${i}: warm key differs from ${name}`);
    }
  }
  row.identicalObservableResult = true;
  result.workloads.push(row);
}
if (output) await writeFile(resolve(output), `${JSON.stringify(result, null, 2)}\n`);
else process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
process.stderr.write(`Measured ${selected.length} gap workloads; all three artifacts agree.\n`);
