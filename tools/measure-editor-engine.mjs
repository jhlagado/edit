// Complete-command measurements against the original and milestone 1 baselines. Run from any directory; writes only --output.
import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { assembleCurrent, loadBaseline, memoryAccounts, createEngineMachine,
  beginSession, executeCommands, executeRoutine, engineSnapshot, snapshotDigest,
  physicalFile, writeWord, sha256 } from "../test/support/editor-engine-harness.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const option = name => { const i = args.indexOf(name); return i < 0 ? undefined : args[i + 1]; };
const mode = option("--mode") ?? "compare";
assert.ok(["baseline", "current", "compare"].includes(mode), "--mode baseline|current|compare");
const only = option("--only");
const output = option("--output");
const pattern = Buffer.from("proc main()\n  let value = 42; // ordinary source text\nend\n", "ascii");
const source = length => Uint8Array.from({ length }, (_, i) => pattern[i % pattern.length]);
const workloads = [];
for (const size of [512, 16384, 47072]) {
  for (const position of ["beginning", "middle", "end"]) {
    workloads.push({ name: `typing-${size}-${position}`, text: source(size),
      cursor: position === "beginning" ? 0 : position === "middle" ? size >>> 1 : size,
      commands: Array.from(Buffer.from("abcdefgh")),
      description: "Eight complete successive printable-key commands; fixture cursor placement and initial layout excluded, reported separately." });
  }
}
workloads.push({ name: "far-jump-search-and-type-16384", text: Buffer.concat([Buffer.from(source(16377)), Buffer.from("\nTARGET")]),
  commands: [6, ...Buffer.from("TARGET"), 13, ...Buffer.from("abcdefgh")],
  description: "Complete forward-search prompt/scan to far target followed by eight complete typing commands." });
workloads.push({ name: "alternating-far-jumps-16384", text: Buffer.concat([Buffer.from("ORIGIN\n"), Buffer.from(source(16370)), Buffer.from("\nTARGET")]),
  commands: [6, ...Buffer.from("TARGET"), 13, 120, 6, ...Buffer.from("ORIGIN"), 13, 121],
  description: "Two distant jumps through real committed-search commands, each followed by one insertion; includes prompt/scan/render." });
workloads.push({ name: "long-printable-16384", text: new Uint8Array(16384).fill(120), cursor: 8192,
  commands: [121], description: "One complete insertion in a long printable line; horizontal-follow rendering included." });
workloads.push({ name: "long-tabs-8193", text: new Uint8Array(8193).fill(9), cursor: 8193,
  commands: [120], description: "One complete insertion beyond visual column65535; tab expansion and horizontal-follow included." });
workloads.push({ name: "search-no-match-16384", text: source(16384), commands: [6, ...Buffer.from("MISSING"), 13],
  description: "Complete query entry, failed full wrap, bell and final render." });
for (const size of [16384, 47072]) workloads.push({ name: `save-${size}`, text: source(size), commands: [19],
  description: "Complete Save key, recoverable file transaction and final render; fake BDOS work counted separately." });
workloads.push({ name: "capacity-reject-47104", text: source(47104), commands: [13],
  description: "Complete CRLF insertion rejection at full capacity, bell and render." });

const dependencyLock = JSON.parse(await readFile(resolve(root, "package-lock.json"), "utf8"));
const baseline = await loadBaseline();
const milestone1 = mode === "compare" ? await loadBaseline(resolve(root, "test/fixtures/editor-engine-milestone1.json")) : undefined;
const current = mode === "baseline" ? undefined : await assembleCurrent(root);
const selected = workloads.filter(w => !only || w.name.includes(only));
assert.ok(selected.length, "no matching workload");
const result = { format: mode === "compare" ? "edit-engine-command-measurements-v2" : "edit-engine-command-measurements-v1", mode,
  ...(mode === "compare" ? { comparisonLabels: { baseline: "original frozen editor", milestone1: "completed milestone 1 contiguous editor", current: "current assembled candidate" } } : {}),
  runtime: { node: process.version,
    pinnedRuntime: dependencyLock.packages["node_modules/@jhlagado/debug80-runtime"].resolved,
    runtimeSourceSha256: sha256(await readFile(resolve(root, "node_modules/@jhlagado/debug80-runtime/dist/z80/runtime.js"))),
    cpuSourceSha256: sha256(await readFile(resolve(root, "node_modules/@jhlagado/debug80-runtime/dist/z80/cpu.js"))) },
  accounting: { cpu: "Executed editor Z80 instructions/T-states; fake BDOS execution costs excluded.",
    instructionUnit: "One runtime.step; repeated block instructions may be one step with full repeated T-states.",
    textReadBytes: "All CPU memory-read callbacks inside fixed text arena; repeated reads counted repeatedly.",
    textCopyReadBytes: "Subset during LDI/LDD/LDIR/LDDR; includes text-to-text shifts and text-to-DMA copies.",
    textScalarReadBytes: "Other text-arena reads; scan/read activity, not unique bytes or high-level scan invocations.",
    storage: "Successful128-byte fake BDOS records plus calls; no physical latency/durability implied.",
    setup: "Entry/load/render and fixture cursor/layout are excluded from command boundary and separately recorded.",
    boundary: "First EditorMainLoop before input through EditorMainLoop after final command/render; no uncounted redraw inside boundary.",
    hostLatency: "Not measured; no inferred keystroke wall latency." },
  artifacts: { baseline: { sha256: baseline.sha256, provenance: baseline.provenance, accounts: memoryAccounts(baseline) },
    ...(milestone1 ? { milestone1: { sha256: milestone1.sha256, provenance: milestone1.provenance, accounts: memoryAccounts(milestone1) } } : {}),
    ...(current ? { current: { sha256: current.sha256, accounts: memoryAccounts(current) } } : {}) },
  workloads: [] };

function measure(artifact, workload) {
  const machine = createEngineMachine(artifact, { files: { "INPUT.NU": physicalFile(workload.text) } });
  const setup = { entry: beginSession(machine) };
  if (workload.cursor !== undefined) {
    writeWord(machine.memory, machine.symbol("EditorCursor"), workload.cursor);
    setup.fixtureLayout = executeRoutine(machine, "EditorRender");
  }
  const metrics = executeCommands(machine, workload.commands);
  const snapshot = engineSnapshot(machine);
  if (workload.name.startsWith("save-")) assert.deepEqual(snapshot.files["INPUT.NU"], Array.from(physicalFile(workload.text)), "saved records differ");
  if (workload.name.startsWith("capacity-reject")) assert.deepEqual(snapshot.text, Array.from(workload.text), "capacity rejection changed text");
  return { setup, metrics, snapshot: snapshotDigest(snapshot) };
}
for (const workload of selected) {
  process.stderr.write(`Measuring ${workload.name}\n`);
  const row = { name: workload.name, description: workload.description,
    input: { bytes: workload.text.length, sha256: sha256(workload.text), cursor: workload.cursor ?? 0,
      commandBytes: workload.commands },
    ...(mode !== "current" ? { baseline: measure(baseline, workload) } : {}),
    ...(milestone1 ? { milestone1: measure(milestone1, workload) } : {}),
    ...(current ? { current: measure(current, workload) } : {}) };
  if (mode === "compare") {
    assert.deepEqual(row.current.snapshot, row.baseline.snapshot, `${workload.name}: observable state differs from original`);
    assert.deepEqual(row.current.snapshot, row.milestone1.snapshot, `${workload.name}: observable state differs from milestone 1`);
    row.identicalObservableResult = true;
  }
  result.workloads.push(row);
}
if (output) await writeFile(resolve(output), `${JSON.stringify(result, null, 2)}\n`);
else process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
process.stderr.write(`Measured ${selected.length} workloads (${mode}); exact results ${output ?? "on stdout"}.\n`);
