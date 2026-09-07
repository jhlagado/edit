// Development-only headless engine harness. No executable test is imported.
// BDOS/file/terminal model follows test/prove-editor.mjs; it is not real CP/M.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createCpm22Terminal } from "@jhlagado/debug80-runtime/platforms/cpm22/terminal";
import { createZ80Runtime } from "@jhlagado/debug80-runtime/z80/runtime";
import { assembleProjectOwnedAtomArtifacts, projectOwnedCandidates, symbolsFromDebugMap } from "../../tools/atom-assembly.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const RETURN_ADDRESS = 0x0040;
export const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
export { readWord, writeWord, writeFcb, physicalFile, logicalFileBytes };

export async function loadBaseline(path = join(ROOT, "test/fixtures/editor-engine-baseline.json")) {
  const fixture = JSON.parse(await readFile(path, "utf8"));
  const bytes = Uint8Array.from(Buffer.from(fixture.binaryBase64, "base64"));
  assert.equal(bytes.length, fixture.bytes);
  assert.equal(sha256(bytes), fixture.sha256, "frozen baseline checksum");
  return { ...fixture, bytes, artifactBytes: bytes.length };
}

export async function assembleCurrent(root = ROOT) {
  const artifacts = await assembleProjectOwnedAtomArtifacts({
    outputDirectory: join(root,"src"),
    candidate:projectOwnedCandidates.find(({name})=>name==="editor.asm"),
    base:0x100,entryAddress:0x100,
  });
  return {bytes:artifacts.bytes,artifactBytes:artifacts.bytes.length,
    sha256:sha256(artifacts.bytes),loadAddress:0x100,
    symbols:symbolsFromDebugMap(artifacts.debugMap)};
}

export function memoryAccounts(artifact) {
  const s = artifact.symbols;
  return { artifactBytes: artifact.bytes.length,
    entryBytes: s.EditorCodeStart - s.EditorTransientStart,
    codeBytes: s.EditorCodeEnd - s.EditorCodeStart,
    immutableBytes: s.EditorImmutableEnd - s.EditorImmutableStart,
    workspaceBytes: s.EditorWorkspaceEnd - s.EditorWorkspaceBase,
    workspaceCapacity: s.EditorWorkspaceLimit - s.EditorWorkspaceBase,
    textCapacity: s.EditorTextLimit - s.EditorTextBase,
    reservedStackBytes: s.EditorStackTop - s.EditorStackFloor,
    codeRoom: s.EditorWorkspaceBase - s.EditorResidentEnd };
}

function readWord(memory, address) {
  return memory[address] | (memory[address + 1] << 8);
}

function writeWord(memory, address, value) {
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
}

function canonicalName(memory, fcbAddress) {
  const name = Buffer.from(memory.slice(fcbAddress + 1, fcbAddress + 9))
    .toString("ascii")
    .trimEnd();
  const extension = Buffer.from(memory.slice(fcbAddress + 9, fcbAddress + 12))
    .toString("ascii")
    .trimEnd();
  return extension.length === 0 ? name : `${name}.${extension}`;
}

function writeFcb(memory, address, nameSource) {
  const [name, extension = ""] = nameSource.toUpperCase().split(".");
  memory.fill(0, address, address + 36);
  memory.fill(0x20, address + 1, address + 12);
  memory.set(Buffer.from(name.padEnd(8).slice(0, 8), "ascii"), address + 1);
  memory.set(
    Buffer.from(extension.padEnd(3).slice(0, 3), "ascii"),
    address + 9,
  );
}

function physicalFile(logicalBytes) {
  if (logicalBytes.length === 0) return new Uint8Array();
  const physical = new Uint8Array(
    Math.ceil(logicalBytes.length / 128) * 128,
  ).fill(0x1a);
  physical.set(logicalBytes);
  return physical;
}

function logicalFileBytes(physicalBytes) {
  const eof = physicalBytes.indexOf(0x1a);
  return physicalBytes.slice(0, eof === -1 ? physicalBytes.length : eof);
}

class FakeBdos {
  constructor(memory, dma, files = {}, failures = []) {
    this.memory = memory;
    this.files = new Map(
      Object.entries(files).map(([name, bytes]) => [
        name,
        Uint8Array.from(bytes),
      ]),
    );
    this.failures = new Map();
    for (const failure of failures) {
      this.failures.set(failure, (this.failures.get(failure) ?? 0) + 1);
    }
    this.cursors = new Map();
    this.dma = dma;
    this.outputBytes = [];
    this.calls = {};
    this.recordsRead = 0;
    this.recordsWritten = 0;
    this.events = [];
    this.input = [];
    this.terminal = createCpm22Terminal();
  }

  consumeFailure(event) {
    const remaining = this.failures.get(event) ?? 0;
    if (remaining === 0) return false;
    if (remaining === 1) this.failures.delete(event);
    else this.failures.set(event, remaining - 1);
    return true;
  }

  fileEvent(kind, address, targetAddress) {
    const name = canonicalName(this.memory, address);
    const event =
      targetAddress === undefined
        ? `${kind}:${name}`
        : `${kind}:${name}->${canonicalName(this.memory, targetAddress)}`;
    this.events.push(event);
    return { event, name };
  }

  invoke(cpu) {
    const functionNumber = cpu.c & 0xff;
    const address = ((cpu.d << 8) | cpu.e) & 0xffff;
    this.calls[functionNumber] = (this.calls[functionNumber] ?? 0) + 1;
    let result = 0;
    if (functionNumber === 6) {
      if (cpu.e === 0xff) result = this.input.shift() ?? 0;
      else { this.outputBytes.push(cpu.e); this.terminal.writeOutput(cpu.e); }
    } else if (functionNumber === 15) {
      const { event, name } = this.fileEvent("open", address);
      if (this.consumeFailure(event) || !this.files.has(name)) result = 0xff;
      else this.cursors.set(address, 0);
    } else if (functionNumber === 16) {
      const { event } = this.fileEvent("close", address);
      if (this.consumeFailure(event)) result = 0xff;
    } else if (functionNumber === 19) {
      const { event, name } = this.fileEvent("delete", address);
      if (this.consumeFailure(event) || !this.files.delete(name)) result = 0xff;
    } else if (functionNumber === 20) {
      const { event, name } = this.fileEvent("read", address);
      const file = this.files.get(name);
      const cursor = this.cursors.get(address) ?? 0;
      if (this.consumeFailure(event)) result = 2;
      else if (file === undefined || cursor >= file.length) result = 1;
      else {
        this.recordsRead++;
        this.memory.fill(0x1a, this.dma, this.dma + 128);
        this.memory.set(file.slice(cursor, cursor + 128), this.dma);
        this.cursors.set(address, cursor + 128);
      }
    } else if (functionNumber === 21) {
      const { event, name } = this.fileEvent("write", address);
      const cursor = this.cursors.get(address) ?? 0;
      if (this.consumeFailure(event)) result = 1;
      else {
        this.recordsWritten++;
        const previous = this.files.get(name) ?? new Uint8Array();
        const next = new Uint8Array(Math.max(previous.length, cursor + 128));
        next.set(previous);
        next.set(this.memory.slice(this.dma, this.dma + 128), cursor);
        this.files.set(name, next);
        this.cursors.set(address, cursor + 128);
      }
    } else if (functionNumber === 22) {
      const { event, name } = this.fileEvent("make", address);
      if (this.consumeFailure(event) || this.files.has(name)) result = 0xff;
      else {
        this.files.set(name, new Uint8Array());
        this.cursors.set(address, 0);
      }
    } else if (functionNumber === 23) {
      const targetAddress = address + 16;
      const { event, name } = this.fileEvent("rename", address, targetAddress);
      const target = canonicalName(this.memory, targetAddress);
      if (
        this.consumeFailure(event) ||
        !this.files.has(name) ||
        this.files.has(target)
      ) {
        result = 0xff;
      } else {
        this.files.set(target, this.files.get(name));
        this.files.delete(name);
      }
    } else if (functionNumber === 26) {
      this.dma = address;
    } else {
      throw new Error(`unsupported fake BDOS function ${functionNumber}`);
    }

    const returnAddress = readWord(this.memory, cpu.sp);
    cpu.sp = (cpu.sp + 2) & 0xffff;
    cpu.pc = returnAddress;
    cpu.a = result & 0xff;
    cpu.flags.C = 0;
  }
}

/** Counters include executed editor Z80 instructions and memory callbacks only.
 * Fake BDOS CPU cycles are excluded; its calls, records and console bytes are separate.
 * Copy means LDI/LDD/LDIR/LDDR reads from the text arena. Scalar reads are all other
 * CPU reads of arena bytes (navigation, render, match, validation, etc.), not unique bytes.
 */
export function createEngineMachine(artifact, { files = {}, failures = [] } = {}) {
  const symbol = (name) => {
    const address = artifact.symbols[name];
    assert.equal(typeof address, "number", `missing symbol ${name}`);
    return address;
  };
  const initial = new Uint8Array(65536);
  initial.set(artifact.bytes, artifact.loadAddress ?? 0x100);
  const runtime = createZ80Runtime({ memory: initial, startAddress: 0x100 }, 0x100);
  const memory = runtime.hardware.memory;
  memory.fill(0xa5, symbol("EditorWorkspaceEnd"), symbol("EditorWorkspaceLimit"));
  memory.fill(0xc7, symbol("EditorTextBase"), symbol("EditorTextLimit"));
  memory.fill(0x5a, symbol("EditorStackTop"));
  const bdos = new FakeBdos(memory, symbol("EditorDma"), files, failures);
  const machine = { artifact, symbol, runtime, memory, bdos, activeMetrics: undefined };
  const originalRead = runtime.hardware.memRead;
  const originalWrite = runtime.hardware.memWrite;
  const textBase = symbol("EditorTextBase"), textLimit = symbol("EditorTextLimit");
  const inText = (address) => address >= textBase && address < textLimit;
  runtime.hardware.memRead = (address) => {
    const m = machine.activeMetrics;
    if (m && inText(address)) {
      m.textReadBytes++;
      if (machine.blockCopy) m.textCopyReadBytes++;
      else m.textScalarReadBytes++;
    }
    return originalRead(address);
  };
  runtime.hardware.memWrite = (address, value) => {
    if (machine.activeMetrics && inText(address)) machine.activeMetrics.textWriteBytes++;
    originalWrite(address, value);
  };
  machine.assertGuards = () => {
    assert.ok(memory.slice(symbol("EditorWorkspaceEnd"), symbol("EditorWorkspaceLimit")).every(x => x === 0xa5), "workspace overflow");
    if (machine.highGuard) assert.deepEqual(memory.slice(symbol("EditorStackTop")), machine.highGuard, "high memory changed");
  };
  return machine;
}

function runBoundary(machine, boundary, done, maxInstructions = 100_000_000) {
  const { runtime, memory, bdos } = machine;
  const m = { boundary, instructions: 0, tStates: 0, textReadBytes: 0,
    textCopyReadBytes: 0, textScalarReadBytes: 0, textWriteBytes: 0 };
  const outputStart = bdos.outputBytes.length;
  const readStart = bdos.recordsRead, writeStart = bdos.recordsWritten;
  const callsStart = { ...bdos.calls };
  const startSp = runtime.cpu.sp;
  let minimumSp = startSp;
  machine.activeMetrics = m;
  try {
    do {
      assert.ok(m.instructions < maxInstructions, `${boundary}: instruction limit`);
      if (runtime.cpu.pc === 5) bdos.invoke(runtime.cpu);
      else {
        const pc = runtime.cpu.pc;
        machine.blockCopy = memory[pc] === 0xed && [0xa0,0xa8,0xb0,0xb8].includes(memory[(pc + 1) & 65535]);
        const step = runtime.step();
        m.instructions++;
        m.tStates += step.cycles ?? 0;
      }
      minimumSp = Math.min(minimumSp, runtime.cpu.sp);
    } while (!done());
  } finally { machine.activeMetrics = undefined; machine.blockCopy = false; }
  m.terminalBytes = bdos.outputBytes.length - outputStart;
  m.recordsRead = bdos.recordsRead - readStart;
  m.recordsWritten = bdos.recordsWritten - writeStart;
  m.bdosCalls = Object.fromEntries(Object.entries(bdos.calls).map(([k,v]) => [k,v - (callsStart[k] ?? 0)]).filter(([,v]) => v));
  m.minimumSp = minimumSp;
  m.stackBytesBelowStart = Math.max(0, startSp - minimumSp);
  m.stackDepthFromPrivateTop = Math.max(0, machine.symbol("EditorStackTop") - minimumSp);
  m.returnPc = runtime.cpu.pc;
  m.finalSp = runtime.cpu.sp;
  machine.assertGuards();
  return m;
}

/** Execute actual entry/load/initial render and pause before the first key read. */
export function beginSession(machine, commandTail = "INPUT.NU") {
  const { memory, runtime, symbol } = machine;
  const tail = Buffer.from(commandTail, "ascii");
  assert.ok(tail.length <= 127);
  memory[0x80] = tail.length; memory.set(tail, 0x81);
  runtime.cpu.sp = 0xe8fe;
  writeWord(memory, runtime.cpu.sp, RETURN_ADDRESS);
  machine.highGuard = memory.slice(symbol("EditorStackTop"));
  runtime.cpu.pc = symbol("EditorEntry");
  const result = runBoundary(machine, "EditorEntry -> EditorMainLoop (load + initial render)", () => runtime.cpu.pc === symbol("EditorMainLoop") || runtime.cpu.pc === RETURN_ADDRESS);
  assert.equal(runtime.cpu.pc, symbol("EditorMainLoop"), "entry failed before input boundary");
  return result;
}

/** Every byte goes through the real raw dispatcher. Stops after final command's render. */
export function executeCommands(machine, input, { boundary = "EditorMainLoop -> EditorMainLoop (dispatch + command + render)", maxInstructions } = {}) {
  const { runtime, symbol, bdos } = machine;
  assert.equal(runtime.cpu.pc, symbol("EditorMainLoop"), "not at command boundary");
  assert.equal(bdos.input.length, 0);
  assert.ok(input.length > 0);
  bdos.input.push(...input);
  const startSp = runtime.cpu.sp;
  const result = runBoundary(machine, boundary, () => (runtime.cpu.pc === symbol("EditorMainLoop") && bdos.input.length === 0) || runtime.cpu.pc === RETURN_ADDRESS, maxInstructions);
  assert.equal(bdos.input.length, 0, "command exited with unconsumed input");
  if (runtime.cpu.pc === symbol("EditorMainLoop")) assert.equal(runtime.cpu.sp, startSp, "command stack mismatch");
  else assert.equal(runtime.cpu.sp, 0xe900, "entry caller stack mismatch");
  return result;
}

/** Semantic routine proof boundary: separate from complete-command cost. */
export function executeRoutine(machine, name, { registers = {}, input = [], maxInstructions } = {}) {
  const { runtime, symbol, memory } = machine;
  const savedPc = runtime.cpu.pc, savedSp = runtime.cpu.sp;
  Object.assign(runtime.cpu, { a: 0,b: 0,c: 0,d: 0,e: 0,h: 0,l: 0, ...registers });
  runtime.cpu.flags.C = 0;
  runtime.cpu.sp = 0xe2fe;
  writeWord(memory, runtime.cpu.sp, RETURN_ADDRESS);
  runtime.cpu.pc = symbol(name);
  machine.bdos.input.push(...input);
  const result = runBoundary(machine, `${name} entry -> RET (semantic only; no implied render)`, () => runtime.cpu.pc === RETURN_ADDRESS, maxInstructions);
  assert.equal(runtime.cpu.sp, 0xe300, `${name} stack mismatch`);
  result.a = runtime.cpu.a; result.carry = runtime.cpu.flags.C !== 0;
  result.hl = (runtime.cpu.h << 8) | runtime.cpu.l;
  runtime.cpu.pc = savedPc; runtime.cpu.sp = savedSp;
  return result;
}

/** Test-only physical observation, independent of production mapping routines. */
export function logicalDocument(machine) {
  const {memory, symbol, artifact} = machine;
  const base = symbol("EditorTextBase");
  const length = readWord(memory, symbol("EditorLength"));
  if (artifact.symbols.EditorDocumentGapStart === undefined) return memory.slice(base, base + length);
  const start = readWord(memory, symbol("EditorDocumentGapStart"));
  const end = readWord(memory, symbol("EditorDocumentGapEnd"));
  const capacity = symbol("EditorTextLimit") - base;
  assert.ok(0 <= start && start <= end && end <= capacity, "gap bounds");
  assert.equal(length, capacity - (end - start), "gap length invariant");
  const result = new Uint8Array(length);
  result.set(memory.slice(base, base + start));
  result.set(memory.slice(base + end, base + capacity), start);
  return result;
}

/** Fixture setup only: never charge a direct placement as an executed edit. */
export function seedDocument(machine, bytes, {gapAt = bytes.length} = {}) {
  const {memory, symbol, artifact} = machine;
  const base = symbol("EditorTextBase"), capacity = symbol("EditorTextLimit") - base;
  assert.ok(bytes.length <= capacity && gapAt >= 0 && gapAt <= bytes.length);
  memory.fill(0xc7, base, base + capacity);
  writeWord(memory, symbol("EditorLength"), bytes.length);
  if (artifact.symbols.EditorDocumentPendingChanges !== undefined) {
    memory[symbol("EditorDocumentPendingChanges")] = 2;
  }
  if (artifact.symbols.EditorDocumentGapStart === undefined) memory.set(bytes, base);
  else {
    const end = gapAt + capacity - bytes.length;
    memory.set(bytes.slice(0, gapAt), base);
    memory.set(bytes.slice(gapAt), base + end);
    writeWord(memory, symbol("EditorDocumentGapStart"), gapAt);
    writeWord(memory, symbol("EditorDocumentGapEnd"), end);
  }
}

export function engineSnapshot(machine) {
  const { memory, symbol, bdos } = machine;
  const length = readWord(memory, symbol("EditorLength"));
  const visual = name => readWord(memory, symbol(name)) + memory[symbol(`${name}High`)] * 65536;
  const screen = bdos.terminal.snapshot();
  return { length,
    text: Array.from(logicalDocument(machine)),
    cursor: readWord(memory, symbol("EditorCursor")), top: readWord(memory, symbol("EditorTop")),
    horizontal: visual("EditorHorizontal"), desiredColumn: visual("EditorDesiredColumn"),
    flags: memory[symbol("EditorFlags")], status: memory[symbol("EditorStatus")],
    query: Array.from(memory.slice(symbol("EditorQueryBuffer"), symbol("EditorQueryBuffer") + memory[symbol("EditorQueryLength")])),
    cells: Array.from(screen.cells), attributes: Array.from(screen.attributes),
    cursorRow: screen.cursorRow, cursorColumn: screen.cursorColumn, bellCount: screen.bellCount,
    files: Object.fromEntries([...bdos.files].sort(([a],[b]) => a.localeCompare(b)).map(([name, bytes]) => [name, Array.from(bytes)])) };
}

export function snapshotDigest(snapshot) {
  const { text, cells, attributes, files, ...state } = snapshot;
  return { ...state, textSha256: sha256(Uint8Array.from(text)),
    cellsSha256: sha256(Uint8Array.from(cells)), attributesSha256: sha256(Uint8Array.from(attributes)),
    files: Object.fromEntries(Object.entries(files).map(([name, bytes]) => [name, { bytes: bytes.length, sha256: sha256(Uint8Array.from(bytes)) }])) };
}
