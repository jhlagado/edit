import assert from "node:assert/strict";
import { logicalDocument, seedDocument } from "./support/editor-engine-harness.mjs";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

import {
  CPM22_TERMINAL_ATTR_REVERSE,
  createCpm22Terminal,
} from "@jhlagado/debug80-runtime/platforms/cpm22/terminal";
import { createZ80Runtime } from "@jhlagado/z80-runtime/z80/runtime";
import {
  assembleProjectOwnedAtomArtifacts,
  projectOwnedCandidates,
  symbolsFromDebugMap,
} from "../tools/atom-assembly.mjs";
import {
  configureImage,
  readConfiguration,
} from "../tools/configure.mjs";
import {
  ATTR_REVERSE,
  createScreenTerminal,
} from "./support/screen-terminal.mjs";

const outputDirectory = "src";
const source = join(outputDirectory, "editor.asm");
const RETURN_ADDRESS = 0x0040;
const ENTRY_CALLER_SP = 0xe900;
const WORKSPACE_CANARY = 0xa5;
const TEXT_CANARY = 0xc7;
const HIGH_CANARY = 0x5a;
// BDOS addresses at $0006: a 64 KiB CP/M 2.2 system and TEC-OS.
const HIGH_TPA_TOP = 0xe400;
const LOW_TPA_TOP = 0xb406;

const atomArtifacts = await assembleProjectOwnedAtomArtifacts({
  outputDirectory,
  candidate: projectOwnedCandidates.find(candidate=>candidate.name==="editor.asm"),
  base:0x100,entryAddress:0x100,
});
const binary = { kind: "bin", bytes: atomArtifacts.bytes };
const debugMap = { kind: "d8m", json: atomArtifacts.debugMap };
assert.equal(debugMap.kind, "d8m", "editor proof requires an Atom debug map");
const symbols = symbolsFromDebugMap(debugMap.json);

function symbol(name) {
  const value = symbols[name];
  assert.equal(typeof value, "number", `missing editor symbol ${name}`);
  return value;
}

const memoryLayout = {
  codeStart: symbol("EditorTransientStart"),
  codeEnd: symbol("EditorCodeEnd"),
  immutableStart: symbol("EditorImmutableStart"),
  immutableEnd: symbol("EditorImmutableEnd"),
  residentEnd: symbol("EditorResidentEnd"),
  workspaceStart: symbol("EditorWorkspaceBase"),
  workspaceUsedEnd: symbol("EditorWorkspaceEnd"),
  workspaceEnd: symbol("EditorWorkspaceLimit"),
  textStart: symbol("EditorTextBase"),
  stackSize: symbol("EditorStackSize"),
  textMinimum: symbol("EditorTextMinimum"),
};

// The private stack ends at the BDOS address; the text arena ends at the stack.
function layoutFor(top) {
  const textEnd = top - memoryLayout.stackSize;
  return { top, textEnd, capacity: textEnd - memoryLayout.textStart };
}
const capacity = layoutFor(HIGH_TPA_TOP).capacity;
assert.equal(
  binary.bytes.length,
  memoryLayout.residentEnd - memoryLayout.codeStart,
);
assert.ok(memoryLayout.residentEnd <= memoryLayout.workspaceStart);

function readWord(memory, address) {
  return memory[address] | (memory[address + 1] << 8);
}

function writeWord(memory, address, value) {
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
}

function readVisualColumn(memory, name) {
  return readWord(memory, symbol(name)) + memory[symbol(`${name}High`)] * 65536;
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
  constructor(memory, files = {}, failures = []) {
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
    this.dma = symbol("EditorDma");
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
    let result = 0;
    if (functionNumber === 6) {
      if (cpu.e === 0xff) {
        // A session may observe the screen whenever the editor waits for a key.
        if (this.input.length === 0) this.onIdle?.();
        result = this.input.shift() ?? 0;
      }
      else this.terminal.writeOutput(cpu.e);
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
        this.memory.fill(0x1a, this.dma, this.dma + 128);
        this.memory.set(file.slice(cursor, cursor + 128), this.dma);
        this.cursors.set(address, cursor + 128);
      }
    } else if (functionNumber === 21) {
      const { event, name } = this.fileEvent("write", address);
      const cursor = this.cursors.get(address) ?? 0;
      if (this.consumeFailure(event)) result = 1;
      else {
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

// Routine-level proofs start from the workspace state that EditorEntry
// establishes: the derived arena limit and capacity and the selected screen.
function createMachine({
  files = {},
  failures = [],
  top = HIGH_TPA_TOP,
  columns = 80,
  rows = 24,
  strictTerminal = columns !== 80 || rows !== 24,
  image = binary.bytes,
} = {}) {
  const initial = new Uint8Array(0x10000);
  initial.set(image, memoryLayout.codeStart);
  const runtime = createZ80Runtime({ memory: initial, startAddress: 0 }, 0);
  const memory = runtime.hardware.memory;
  const layout = layoutFor(top);
  writeWord(memory, 6, top);
  memory.fill(
    WORKSPACE_CANARY,
    memoryLayout.workspaceUsedEnd,
    memoryLayout.workspaceEnd,
  );
  memory.fill(TEXT_CANARY, memoryLayout.textStart, layout.textEnd);
  memory.fill(HIGH_CANARY, top, 0x10000);
  writeWord(memory, symbol("EditorTextLimit"), layout.textEnd);
  writeWord(memory, symbol("EditorTextCapacity"), layout.capacity);
  memory[symbol("EditorColumns")] = columns;
  memory[symbol("EditorTextRows")] = rows - 1;
  const bdos = new FakeBdos(memory, files, failures);
  if (strictTerminal) bdos.terminal = createScreenTerminal({ columns, rows });
  return { bdos, layout, memory, runtime };
}

function invokeRoutine(
  machine,
  routine,
  {
    registers = {},
    callerSp = machine.layout.top,
    beforeRun,
    instructionLimit = 20_000_000,
  } = {},
) {
  const cpu = machine.runtime.cpu;
  Object.assign(cpu, {
    a: 0,
    b: 0,
    c: 0,
    d: 0,
    e: 0,
    h: 0,
    l: 0,
    ix: 0x1357,
    iy: 0x2468,
    ...registers,
  });
  cpu.flags.C = 0;
  cpu.sp = callerSp - 2;
  writeWord(machine.memory, cpu.sp, RETURN_ADDRESS);
  cpu.pc = symbol(routine);
  beforeRun?.();
  let instructions = 0;
  let tStates = 0;
  let minimumSp = cpu.sp;
  // EditorEntry ends with a warm boot after it has selected its private stack.
  const warmBootExit = routine === "EditorEntry";
  while (cpu.pc !== RETURN_ADDRESS && !(warmBootExit && cpu.pc === 0)) {
    assert.ok(instructions < instructionLimit, `${routine} did not return`);
    if (cpu.pc === 5) machine.bdos.invoke(cpu);
    else {
      const step = machine.runtime.step();
      instructions += 1;
      tStates += step.cycles ?? 0;
    }
    minimumSp = Math.min(minimumSp, cpu.sp);
  }
  const exit = cpu.pc === 0 ? "warm-boot" : "return";
  if (exit === "return") {
    assert.equal(cpu.sp, callerSp, `${routine} changed its caller stack depth`);
  } else {
    assert.ok(
      cpu.sp <= machine.layout.top &&
        cpu.sp >= machine.layout.top - memoryLayout.stackSize,
      "EditorEntry warm-booted outside its private stack",
    );
  }
  return {
    a: cpu.a,
    carry: cpu.flags.C !== 0,
    exit,
    instructions,
    tStates,
    stackBytes:
      (exit === "warm-boot" && callerSp > machine.layout.top
        ? machine.layout.top
        : callerSp - 2) - minimumSp,
  };
}

function assertCanaries(machine, { high = true } = {}) {
  assert.ok(
    machine.memory
      .slice(memoryLayout.workspaceUsedEnd, memoryLayout.workspaceEnd)
      .every((byte) => byte === WORKSPACE_CANARY),
    "editor wrote beyond fixed workspace",
  );
  if (high) {
    assert.ok(
      machine.memory
        .slice(machine.layout.top, 0x10000)
        .every((byte) => byte === HIGH_CANARY),
      "editor wrote above its private stack partition",
    );
  }
}

function setCommandTail(memory, text) {
  const bytes = Buffer.from(text, "ascii");
  memory[0x80] = bytes.length;
  memory.set(bytes, 0x81);
}

function selectedName(memory) {
  return canonicalName(memory, symbol("EditorFcb"));
}

function installBuffer(machine, bytes, cursor = 0) {
  assert.ok(bytes.length <= machine.layout.capacity);
  machine.memory.fill(
    TEXT_CANARY,
    memoryLayout.textStart,
    machine.layout.textEnd,
  );
  seedDocument(
    { memory: machine.memory, symbol, artifact: { symbols }, layout: machine.layout },
    bytes,
  );
  writeWord(machine.memory, symbol("EditorCursor"), cursor);
  writeWord(machine.memory, symbol("EditorTop"), 0);
  writeWord(machine.memory, symbol("EditorHorizontal"), 0);
  writeWord(machine.memory, symbol("EditorDesiredColumn"), 0);
  machine.memory[symbol("EditorHorizontalHigh")] = 0;
  machine.memory[symbol("EditorDesiredColumnHigh")] = 0;
  machine.memory[symbol("EditorFlags")] = 0;
  machine.memory[symbol("EditorStatus")] = 0;
  machine.memory[symbol("EditorSaveState")] = 0;
  machine.memory[symbol("EditorQueryLength")] = 0;
}

function setQuery(machine, payload, tailSeed = 0x40) {
  assert.ok(payload.length <= symbol("EditorQueryCapacity"));
  const lengthAddress = symbol("EditorQueryLength");
  const bufferAddress = symbol("EditorQueryBuffer");
  machine.memory[lengthAddress] = payload.length;
  machine.memory.set(payload, bufferAddress);
  for (
    let index = payload.length;
    index < symbol("EditorQueryCapacity");
    index += 1
  ) {
    machine.memory[bufferAddress + index] = (tailSeed + index) & 0xff;
  }
}

function queryBytes(machine) {
  const length = machine.memory[symbol("EditorQueryLength")];
  return machine.memory.slice(
    symbol("EditorQueryBuffer"),
    symbol("EditorQueryBuffer") + length,
  );
}

function queryBlock(machine) {
  return machine.memory.slice(
    symbol("EditorQueryLength"),
    symbol("EditorQueryBuffer") + symbol("EditorQueryCapacity"),
  );
}

function bufferBytes(machine) {
  return logicalDocument({ memory: machine.memory, symbol, artifact: { symbols }, layout: machine.layout });
}

function assertUnusedTextCanary(machine) {
  if (symbols.EditorDocumentGapStart !== undefined) {
    // Gap bytes may contain old text after relocation/deletion. They are not
    // an untouched suffix. Assert the representation bounds/length here;
    // outer canaries and gap rejection tests guard illegal writes separately.
    bufferBytes(machine);
    return;
  }
  const length = readWord(machine.memory, symbol("EditorLength"));
  assert.ok(
    machine.memory
      .slice(memoryLayout.textStart + length, machine.layout.textEnd)
      .every((byte) => byte === TEXT_CANARY),
    "editor wrote beyond logical text",
  );
}

function prepareDefaultFcb(machine) {
  writeFcb(machine.memory, symbol("EditorFcb"), "INPUT.NU");
}

const commandMeasurements = {};
{
  const machine = createMachine();
  setCommandTail(machine.memory, "");
  commandMeasurements.default = invokeRoutine(machine, "EditorPrepareCommand");
  assert.equal(commandMeasurements.default.carry, false);
  // No name: the buffer starts new and unnamed.
  assert.equal(machine.memory[symbol("EditorFcb") + 1], 0x20);
  assert.equal(machine.memory[symbol("EditorSaveState")], 0);

  setCommandTail(machine.memory, "  lower.nu  ");
  commandMeasurements.selected = invokeRoutine(machine, "EditorPrepareCommand");
  assert.equal(commandMeasurements.selected.carry, false);
  assert.equal(selectedName(machine.memory), "LOWER.NU");
  assert.notEqual(machine.memory[symbol("EditorSaveState")], 0);

  for (const tail of [
    "A:BAD.NU",
    "*.NU",
    "BAD.$$$",
    "BAD.BAK",
    "ONE.NU TWO.NU",
  ]) {
    setCommandTail(machine.memory, tail);
    const result = invokeRoutine(machine, "EditorPrepareCommand");
    assert.equal(result.carry, true, `accepted invalid command tail ${tail}`);
    assert.equal(result.a, symbol("EditorErrorCommand"));
  }
  assertCanaries(machine);
}

const loadMeasurements = {};
function proveLoad(name, physical, expected, expectedError) {
  const files = physical === undefined ? {} : { "INPUT.NU": physical };
  const machine = createMachine({ files });
  prepareDefaultFcb(machine);
  const result = invokeRoutine(machine, "EditorLoadFile");
  if (expectedError === undefined) {
    assert.equal(result.carry, false, `${name} load failed`);
    assert.deepEqual(bufferBytes(machine), Uint8Array.from(expected));
    assert.equal(readVisualColumn(machine.memory, "EditorHorizontal"), 0);
    assert.equal(readVisualColumn(machine.memory, "EditorDesiredColumn"), 0);
    assertUnusedTextCanary(machine);
  } else {
    assert.equal(result.carry, true, `${name} load unexpectedly succeeded`);
    assert.equal(result.a, expectedError);
  }
  assertCanaries(machine);
  return result;
}

// A missing file opens as a new, empty buffer whatever the command line said;
// only an unnamed buffer skips the open.
loadMeasurements.missing = proveLoad("missing", undefined, []);
{
  const machine = createMachine();
  setCommandTail(machine.memory, "NEW.NU");
  assert.equal(invokeRoutine(machine, "EditorPrepareCommand").carry, false);
  loadMeasurements.explicitMissing = invokeRoutine(machine, "EditorLoadFile");
  assert.equal(loadMeasurements.explicitMissing.carry, false);
  assert.equal(selectedName(machine.memory), "NEW.NU");
  assert.deepEqual(bufferBytes(machine), new Uint8Array());
  for (const name of [
    "EditorLength",
    "EditorCursor",
    "EditorTop",
    "EditorHorizontal",
    "EditorDesiredColumn",
  ]) {
    assert.equal(readWord(machine.memory, symbol(name)), 0, name);
  }
  assert.equal(machine.memory[symbol("EditorQueryLength")], 0);
  assert.equal(machine.memory[symbol("EditorStatus")], 0);
  assert.equal(
    machine.memory[symbol("EditorFlags")],
    symbol("EditorFlagDirty") | symbol("EditorFlagNew"),
  );
  loadMeasurements.explicitMissingRender = invokeRoutine(
    machine,
    "EditorRender",
  );
  const snapshot = machine.bdos.terminal.snapshot();
  assert.equal(
    Buffer.from(snapshot.cells.slice(23 * 80)).toString("ascii"),
    "EDIT NEW.NU *  L1 C1  ^S Save  ^Q Quit".padEnd(80),
  );
  assert.ok(
    snapshot.attributes
      .slice(23 * 80)
      .every((attribute) => attribute === CPM22_TERMINAL_ATTR_REVERSE),
  );
  assert.equal(snapshot.cursorRow, 0);
  assert.equal(snapshot.cursorColumn, 0);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  setCommandTail(machine.memory, "INPUT.NU");
  assert.equal(invokeRoutine(machine, "EditorPrepareCommand").carry, false);
  loadMeasurements.explicitDefaultMissing = invokeRoutine(
    machine,
    "EditorLoadFile",
  );
  assert.equal(loadMeasurements.explicitDefaultMissing.carry, false);
  assert.equal(
    machine.memory[symbol("EditorFlags")],
    symbol("EditorFlagDirty") | symbol("EditorFlagNew"),
  );
}
{
  const content = Buffer.from("EXISTING\r\n", "ascii");
  const machine = createMachine({
    files: { "EXIST.NU": physicalFile(content) },
  });
  setCommandTail(machine.memory, "EXIST.NU");
  assert.equal(invokeRoutine(machine, "EditorPrepareCommand").carry, false);
  loadMeasurements.explicitExisting = invokeRoutine(machine, "EditorLoadFile");
  assert.equal(loadMeasurements.explicitExisting.carry, false);
  assert.deepEqual(bufferBytes(machine), Uint8Array.from(content));
  assert.equal(machine.memory[symbol("EditorFlags")], 0);
}
loadMeasurements.empty = proveLoad("empty", new Uint8Array(), []);
loadMeasurements.representative = proveLoad(
  "representative",
  physicalFile(Buffer.from("A\tB\r\nC\n", "ascii")),
  Buffer.from("A\tB\r\nC\n", "ascii"),
);
{
  for (const [label, filename] of [
    ["atomSource", "atom-example.asm"],
    ["nucleusSource", "nucleus-example.nu"],
  ]) {
    const expected = new Uint8Array(await readFile(join("test/fixtures", filename)));
    const cpmName = filename.endsWith(".asm") ? "INPUT.ASM" : "INPUT.NU";
    const physical = physicalFile(expected);
    const machine = createMachine({ files: { [cpmName]: physical } });
    writeFcb(machine.memory, symbol("EditorFcb"), cpmName);
    loadMeasurements[label] = invokeRoutine(machine, "EditorLoadFile");
    assert.equal(loadMeasurements[label].carry, false);
    assert.deepEqual(bufferBytes(machine), expected);
    assertUnusedTextCanary(machine);
    assertCanaries(machine);
  }
}
loadMeasurements.textEof = proveLoad(
  "text EOF",
  Uint8Array.from([0x41, 0x1a, 0x01, 0x42]),
  Uint8Array.of(0x41),
);
proveLoad(
  "invalid control",
  Uint8Array.from([0x41, 0x01, 0x1a]),
  [],
  symbol("EditorErrorText"),
);
proveLoad(
  "bare CR",
  Uint8Array.from([0x41, 0x0d, 0x1a]),
  [],
  symbol("EditorErrorText"),
);
loadMeasurements.full = proveLoad(
  "exact capacity",
  new Uint8Array(capacity).fill(0x41),
  new Uint8Array(capacity).fill(0x41),
);
{
  const machine = createMachine({
    files: { "INPUT.NU": new Uint8Array(capacity + 1).fill(0x41) },
  });
  prepareDefaultFcb(machine);
  const result = invokeRoutine(machine, "EditorLoadFile");
  assert.equal(result.carry, true);
  assert.equal(result.a, symbol("EditorErrorCapacity"));
  assert.equal(readWord(machine.memory, symbol("EditorLength")), capacity);
  assert.ok(
    machine.memory
      .slice(memoryLayout.textStart, machine.layout.textEnd)
      .every((byte) => byte === 0x41),
  );
  assertCanaries(machine);
  loadMeasurements.overflow = result;
}

const editMeasurements = {};
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("ABCD", "ascii"), 0);
  editMeasurements.insertStart = invokeRoutine(
    machine,
    "EditorBufferInsertByte",
    {
      registers: { a: 0x58 },
    },
  );
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("XABCD", "ascii")),
  );
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 1);

  writeWord(machine.memory, symbol("EditorCursor"), 3);
  editMeasurements.insertMiddle = invokeRoutine(
    machine,
    "EditorBufferInsertByte",
    {
      registers: { a: 0x59 },
    },
  );
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("XABYCD", "ascii")),
  );

  writeWord(machine.memory, symbol("EditorCursor"), 6);
  editMeasurements.insertEnd = invokeRoutine(
    machine,
    "EditorBufferInsertByte",
    {
      registers: { a: 0x5a },
    },
  );
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("XABYCDZ", "ascii")),
  );
  assertUnusedTextCanary(machine);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("A\r\nB\nC", "ascii"), 3);
  editMeasurements.backspaceCrlf = invokeRoutine(
    machine,
    "EditorBufferBackspace",
  );
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("AB\nC", "ascii")),
  );
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 1);

  writeWord(machine.memory, symbol("EditorCursor"), 2);
  editMeasurements.deleteLf = invokeRoutine(machine, "EditorBufferDelete");
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("ABC", "ascii")),
  );
  assertCanaries(machine);
}
{
  const cases = [
    ["backspaceByte", "AB", 2, "EditorBufferBackspace", "A", 1],
    ["backspaceLf", "A\nB", 2, "EditorBufferBackspace", "AB", 1],
    ["deleteByte", "AB", 0, "EditorBufferDelete", "B", 0],
    ["deleteCrlf", "A\r\nB", 1, "EditorBufferDelete", "AB", 1],
  ];
  for (const [
    label,
    input,
    cursor,
    routine,
    expected,
    expectedCursor,
  ] of cases) {
    const machine = createMachine();
    installBuffer(machine, Buffer.from(input, "ascii"), cursor);
    editMeasurements[label] = invokeRoutine(machine, routine);
    assert.deepEqual(
      bufferBytes(machine),
      Uint8Array.from(Buffer.from(expected, "ascii")),
    );
    assert.equal(
      readWord(machine.memory, symbol("EditorCursor")),
      expectedCursor,
    );
    assertCanaries(machine);
  }
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("AB", "ascii"), 1);
  editMeasurements.newline = invokeRoutine(
    machine,
    "EditorBufferInsertNewline",
  );
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("A\r\nB", "ascii")),
  );
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 3);
  assertUnusedTextCanary(machine);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, new Uint8Array(capacity).fill(0x41), 100);
  const before = bufferBytes(machine);
  writeWord(machine.memory, symbol("EditorTop"), 42);
  writeWord(machine.memory, symbol("EditorHorizontal"), 9);
  const result = invokeRoutine(machine, "EditorBufferInsertByte", {
    registers: { a: 0x42 },
  });
  assert.equal(result.carry, true);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusFull"),
  );
  assert.equal(readWord(machine.memory, symbol("EditorLength")), capacity);
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 100);
  assert.equal(readWord(machine.memory, symbol("EditorTop")), 42);
  assert.equal(readWord(machine.memory, symbol("EditorHorizontal")), 9);
  assert.deepEqual(bufferBytes(machine), before);
  assertCanaries(machine);
  editMeasurements.full = result;
}
{
  const machine = createMachine();
  installBuffer(machine, new Uint8Array(capacity - 1).fill(0x41), 7);
  const before = bufferBytes(machine);
  const result = invokeRoutine(machine, "EditorBufferInsertNewline");
  assert.equal(result.carry, true);
  assert.equal(readWord(machine.memory, symbol("EditorLength")), capacity - 1);
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 7);
  assert.deepEqual(bufferBytes(machine), before);
  assertCanaries(machine);
  editMeasurements.atomicNewline = result;
}

const navigationMeasurements = {};
for (const column of [0, 1, 7, 8, 247, 248, 255, 256, 32767, 65527, 65528, 65535]) {
  const machine = createMachine();
  const result = invokeRoutine(machine, "EditorNavigationNextTab", {
    registers: { h: column >>> 8, l: column & 255 },
    beforeRun() { machine.runtime.cpu.flags.C = 1; },
  });
  const expected = Math.floor(column / 8) * 8 + 8;
  assert.equal(machine.runtime.cpu.h * 256 + machine.runtime.cpu.l, expected & 65535);
  assert.equal(result.carry, expected > 65535);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  const bytes = Buffer.concat([Buffer.alloc(8192, 9), Buffer.from("\nABC")]);
  installBuffer(machine, bytes, 8192);
  navigationMeasurements.downWide = invokeRoutine(machine, "EditorMoveDown");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), bytes.length,
    "vertical movement must retain visual column 65536");
  assert.equal(readVisualColumn(machine.memory, "EditorDesiredColumn"), 65536);
  invokeRoutine(machine, "EditorMoveUp");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 8192);
  assert.deepEqual(bufferBytes(machine), Uint8Array.from(bytes));
  assertCanaries(machine);
}
// Exercise tab and ordinary-character carries at each reachable high-bit
// boundary, including the maximum legal all-tab buffer. Expected offsets use
// an independent unbounded-integer walk of the source bytes.
for (const width of [65528, 65535, 65536, 65537, 131071, 131072,
  196607, 196608, 262143, 262144, 327679, 327680, capacity * 8]) {
  const machine = createMachine();
  const bytes = Buffer.concat([
    Buffer.alloc(Math.floor(width / 8), 9), Buffer.alloc(width % 8, 0x58),
  ]);
  installBuffer(machine, bytes, bytes.length);
  const result = invokeRoutine(machine, "EditorNavigationCursorColumn");
  assert.equal(result.a * 65536 + machine.runtime.cpu.h * 256 +
    machine.runtime.cpu.l, width);
  invokeRoutine(machine, "EditorEnsureViewport");
  assert.equal(readVisualColumn(machine.memory, "EditorHorizontal"), width - 79);
  assert.equal(machine.memory[symbol("EditorCursorScreenColumn")], 79);
  for (const target of [width - 9, width - 1, width, width + 1]) {
    let column = 0;
    let expected = 0;
    for (const byte of bytes) {
      const next = byte === 9 ? Math.floor(column / 8) * 8 + 8 : column + 1;
      if (next > target) break;
      column = next;
      expected++;
    }
    invokeRoutine(machine, "EditorNavigationOffsetForColumn", {
      registers: { a: target >>> 16, d: (target >>> 8) & 255, e: target & 255 },
    });
    assert.equal(machine.runtime.cpu.h * 256 + machine.runtime.cpu.l, expected,
      `offset at column ${target} in width ${width}`);
  }
  assert.deepEqual(bufferBytes(machine), Uint8Array.from(bytes));
  assertUnusedTextCanary(machine);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  const wide = Buffer.concat([Buffer.alloc(8191, 9), Buffer.from("12345678")]);
  const bytes = Buffer.concat([wide, Buffer.from("\r\nx\r\n"), wide]);
  installBuffer(machine, bytes, wide.length);
  invokeRoutine(machine, "EditorMoveDown");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), wide.length + 3);
  assert.equal(readVisualColumn(machine.memory, "EditorDesiredColumn"), 65536);
  invokeRoutine(machine, "EditorMoveDown");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), bytes.length);
  invokeRoutine(machine, "EditorMoveUp");
  invokeRoutine(machine, "EditorMoveUp");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), wide.length);
  invokeRoutine(machine, "EditorMoveLeft");
  invokeRoutine(machine, "EditorMoveDown");
  assert.equal(readVisualColumn(machine.memory, "EditorDesiredColumn"), 65535);
  assertCanaries(machine);
}
for (const [tabCount, suffix] of [[8192, "TAIL"], [8191, "12345678TAIL"],
  [capacity - 4, "TAIL"]]) {
  const machine = createMachine();
  prepareDefaultFcb(machine);
  const bytes = Buffer.concat([Buffer.alloc(tabCount, 9), Buffer.from(suffix)]);
  installBuffer(machine, bytes, bytes.length);
  navigationMeasurements[`wideRender${tabCount}`] = invokeRoutine(machine, "EditorRender");
  const snapshot = machine.bdos.terminal.snapshot();
  assert.equal(Buffer.from(snapshot.cells.slice(0, 80)).toString("ascii"),
    `${" ".repeat(79 - suffix.length)}${suffix} `);
  assert.equal(snapshot.cursorColumn, 79);
  assert.equal(snapshot.cursorRow, 0);
  assert.equal(readVisualColumn(machine.memory, "EditorHorizontal"), tabCount * 8 + suffix.length - 79);
  // Moving back to the start must clear the high viewport byte as well.
  writeWord(machine.memory, symbol("EditorCursor"), 0);
  invokeRoutine(machine, "EditorEnsureViewport");
  assert.equal(readVisualColumn(machine.memory, "EditorHorizontal"), 0);
  assert.equal(machine.memory[symbol("EditorCursorScreenColumn")], 0);
  assert.deepEqual(bufferBytes(machine), Uint8Array.from(bytes));
  assertUnusedTextCanary(machine);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("A\r\nB", "ascii"), 1);
  navigationMeasurements.rightCrlf = invokeRoutine(machine, "EditorMoveRight");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 3);
  navigationMeasurements.leftCrlf = invokeRoutine(machine, "EditorMoveLeft");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 1);
  assertCanaries(machine);
}

const searchMeasurements = {};
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("A\tB\r\n", "ascii"), 0);
  setQuery(machine, Buffer.from("A\tB", "ascii"));
  writeWord(
    machine.memory,
    symbol("EditorRenderPointer"),
    symbol("EditorQueryLength"),
  );
  searchMeasurements.prompt = invokeRoutine(machine, "EditorRenderLiteral", {
    registers: {
      h: symbol("EditorQueryLength") >>> 8,
      l: symbol("EditorQueryLength") & 0xff,
      d: symbol("EditorSearchPrompt") >>> 8,
      e: symbol("EditorSearchPrompt") & 0xff,
    },
  });
  const snapshot = machine.bdos.terminal.snapshot();
  assert.equal(
    Buffer.from(snapshot.cells.slice(23 * 80)).toString("ascii"),
    "Find: A>B".padEnd(80),
  );
  assert.ok(
    snapshot.attributes
      .slice(23 * 80)
      .every((attribute) => attribute === CPM22_TERMINAL_ATTR_REVERSE),
  );
  assert.equal(snapshot.cursorRow, 23);
  assert.equal(snapshot.cursorColumn, 9);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, new Uint8Array(), 0);
  setQuery(machine, new Uint8Array());
  writeWord(
    machine.memory,
    symbol("EditorRenderPointer"),
    symbol("EditorQueryLength"),
  );
  searchMeasurements.emptyPrompt = invokeRoutine(
    machine,
    "EditorRenderLiteral",
    {
      registers: {
        h: symbol("EditorQueryLength") >>> 8,
        l: symbol("EditorQueryLength") & 0xff,
        d: symbol("EditorSearchPrompt") >>> 8,
        e: symbol("EditorSearchPrompt") & 0xff,
      },
    },
  );
  let snapshot = machine.bdos.terminal.snapshot();
  assert.equal(
    Buffer.from(snapshot.cells.slice(23 * 80)).toString("ascii"),
    "Find: ".padEnd(80),
  );
  assert.equal(snapshot.cursorRow, 23);
  assert.equal(snapshot.cursorColumn, 6);

  setQuery(machine, new Uint8Array(64).fill(0x41));
  searchMeasurements.fullPrompt = invokeRoutine(
    machine,
    "EditorRenderLiteral",
    {
      registers: {
        h: symbol("EditorQueryLength") >>> 8,
        l: symbol("EditorQueryLength") & 0xff,
        d: symbol("EditorSearchPrompt") >>> 8,
        e: symbol("EditorSearchPrompt") & 0xff,
      },
    },
  );
  snapshot = machine.bdos.terminal.snapshot();
  assert.equal(
    Buffer.from(snapshot.cells.slice(23 * 80)).toString("ascii"),
    `Find: ${"A".repeat(64)}`.padEnd(80),
  );
  assert.equal(snapshot.cursorRow, 23);
  assert.equal(snapshot.cursorColumn, 70);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("XXOLX", "ascii"), 0);
  setQuery(machine, Buffer.from("OLD", "ascii"), 0x20);
  machine.bdos.input.push(8, 0x58, 13);
  searchMeasurements.replace = invokeRoutine(machine, "EditorSearchBegin");
  assert.equal(searchMeasurements.replace.carry, false);
  assert.deepEqual(
    queryBytes(machine),
    Uint8Array.from(Buffer.from("OLX", "ascii")),
  );
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 2);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusFound"),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 0);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("ABC", "ascii"), 2);
  setQuery(machine, Buffer.from("OLD", "ascii"), 0x20);
  const beforeQuery = queryBlock(machine);
  const beforeText = bufferBytes(machine);
  writeWord(machine.memory, symbol("EditorTop"), 1);
  writeWord(machine.memory, symbol("EditorHorizontal"), 7);
  machine.memory[symbol("EditorFlags")] = symbol("EditorFlagDirty");
  machine.memory[symbol("EditorStatus")] = symbol("EditorStatusSaved");
  machine.bdos.input.push(8, 0x58, 27);
  searchMeasurements.cancel = invokeRoutine(machine, "EditorSearchBegin");
  assert.equal(searchMeasurements.cancel.carry, false);
  assert.deepEqual(queryBlock(machine), beforeQuery);
  assert.deepEqual(bufferBytes(machine), beforeText);
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 2);
  assert.equal(readWord(machine.memory, symbol("EditorTop")), 1);
  assert.equal(readWord(machine.memory, symbol("EditorHorizontal")), 7);
  assert.equal(
    machine.memory[symbol("EditorFlags")],
    symbol("EditorFlagDirty"),
  );
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusReady"),
  );
  assert.deepEqual(machine.bdos.events, []);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("A", "ascii"), 0);
  setQuery(machine, Buffer.from("A", "ascii"), 0x30);
  const beforeQuery = queryBlock(machine);
  machine.bdos.input.push(8, 13);
  searchMeasurements.emptyReturn = invokeRoutine(machine, "EditorSearchBegin");
  assert.equal(searchMeasurements.emptyReturn.carry, false);
  assert.deepEqual(queryBlock(machine), beforeQuery);
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 0);
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 0);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, new Uint8Array(64).fill(0x41), 0);
  setQuery(machine, new Uint8Array());
  machine.bdos.input.push(...new Uint8Array(65).fill(0x41), 13);
  searchMeasurements.capacity = invokeRoutine(machine, "EditorSearchBegin");
  assert.equal(searchMeasurements.capacity.carry, false);
  assert.equal(
    machine.memory[symbol("EditorQueryLength")],
    symbol("EditorQueryCapacity"),
  );
  assert.deepEqual(queryBytes(machine), new Uint8Array(64).fill(0x41));
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 0);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("A\tB", "ascii"), 0);
  setQuery(machine, new Uint8Array());
  machine.bdos.input.push(8, 127, 1, 9, 13);
  searchMeasurements.controls = invokeRoutine(machine, "EditorSearchBegin");
  assert.equal(searchMeasurements.controls.carry, false);
  assert.deepEqual(queryBytes(machine), Uint8Array.of(9));
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 1);
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 3);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Uint8Array.of(32, 126, 9), 0);
  setQuery(machine, new Uint8Array());
  machine.bdos.input.push(32, 126, 9, 13);
  searchMeasurements.byteOrder = invokeRoutine(machine, "EditorSearchBegin");
  assert.equal(searchMeasurements.byteOrder.carry, false);
  assert.deepEqual(queryBytes(machine), Uint8Array.of(32, 126, 9));
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 0);
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 0);
  assert.equal(
    Buffer.from(machine.bdos.terminal.snapshot().cells.slice(23 * 80)).toString(
      "ascii",
    ),
    "Find:  ~>".padEnd(80),
  );
  assertCanaries(machine);
}

function searchResult(
  label,
  text,
  query,
  cursor,
  routine,
  { bell = 0, carry = false, expectedCursor, expectedStatus },
) {
  const machine = createMachine();
  installBuffer(machine, text, cursor);
  setQuery(machine, query);
  machine.memory[symbol("EditorFlags")] =
    symbol("EditorFlagDirty") | symbol("EditorFlagDesiredValid");
  if (carry) {
    writeWord(machine.memory, symbol("EditorTop"), 1);
    writeWord(machine.memory, symbol("EditorHorizontal"), 7);
  }
  const before = bufferBytes(machine);
  const beforeTop = readWord(machine.memory, symbol("EditorTop"));
  const beforeHorizontal = readWord(machine.memory, symbol("EditorHorizontal"));
  const result = invokeRoutine(machine, routine);
  assert.equal(result.carry, carry, `${label}: wrong carry`);
  assert.equal(
    readWord(machine.memory, symbol("EditorCursor")),
    expectedCursor,
    `${label}: wrong cursor`,
  );
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol(expectedStatus),
    `${label}: wrong status`,
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, bell);
  assert.deepEqual(bufferBytes(machine), before);
  assert.equal(readWord(machine.memory, symbol("EditorTop")), beforeTop);
  assert.equal(
    readWord(machine.memory, symbol("EditorHorizontal")),
    beforeHorizontal,
  );
  assert.notEqual(
    machine.memory[symbol("EditorFlags")] & symbol("EditorFlagDirty"),
    0,
  );
  if (!carry) {
    assert.equal(
      machine.memory[symbol("EditorFlags")] & symbol("EditorFlagDesiredValid"),
      0,
    );
  } else {
    assert.notEqual(
      machine.memory[symbol("EditorFlags")] & symbol("EditorFlagDesiredValid"),
      0,
    );
  }
  assertCanaries(machine);
  return result;
}

{
  const machine = createMachine();
  const text = Buffer.from("ABABA\r\nX\tY\nABA", "ascii");
  installBuffer(machine, text, 0);
  setQuery(machine, Buffer.from("ABA", "ascii"));
  searchMeasurements.first = invokeRoutine(machine, "EditorSearchInitial");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 0);
  searchMeasurements.overlap = invokeRoutine(machine, "EditorSearchRepeat");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 2);
  searchMeasurements.later = invokeRoutine(machine, "EditorSearchRepeat");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 11);
  searchMeasurements.wrap = invokeRoutine(machine, "EditorSearchRepeat");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 0);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusWrapped"),
  );
  assertCanaries(machine);
}

for (const [label, text, query, cursor, routine, expected] of [
  [
    "current",
    "XXABC",
    "ABC",
    2,
    "EditorSearchInitial",
    [2, "EditorStatusFound"],
  ],
  [
    "afterLf",
    "A\nTARGET",
    "TARGET",
    0,
    "EditorSearchInitial",
    [2, "EditorStatusFound"],
  ],
  [
    "afterCrlf",
    "A\r\nTARGET",
    "TARGET",
    0,
    "EditorSearchInitial",
    [3, "EditorStatusFound"],
  ],
  ["tab", "A\tB", "\t", 0, "EditorSearchInitial", [1, "EditorStatusFound"]],
  ["final", "XYZZ", "ZZ", 0, "EditorSearchInitial", [2, "EditorStatusFound"]],
  [
    "selfAfterRing",
    "ABA",
    "ABA",
    0,
    "EditorSearchRepeat",
    [0, "EditorStatusWrapped"],
  ],
]) {
  searchMeasurements[label] = searchResult(
    label,
    Buffer.from(text, "ascii"),
    Buffer.from(query, "ascii"),
    cursor,
    routine,
    { expectedCursor: expected[0], expectedStatus: expected[1] },
  );
}

for (const [label, text, query, cursor, routine, expectedStatus] of [
  [
    "missing",
    "ABCDEFGHI",
    "XYZ",
    4,
    "EditorSearchInitial",
    "EditorStatusNotFound",
  ],
  [
    "longSuffix",
    "ABC",
    "ABCDE",
    2,
    "EditorSearchInitial",
    "EditorStatusNotFound",
  ],
  ["noWrapJoin", "AB", "BA", 1, "EditorSearchInitial", "EditorStatusNotFound"],
  ["crossLf", "A\nB", "AB", 0, "EditorSearchInitial", "EditorStatusNotFound"],
  [
    "crossCrlf",
    "A\r\nB",
    "AB",
    0,
    "EditorSearchInitial",
    "EditorStatusNotFound",
  ],
  ["emptyText", "", "A", 0, "EditorSearchInitial", "EditorStatusNotFound"],
  ["noQuery", "ABC", "", 1, "EditorSearchRepeat", "EditorStatusNoSearch"],
]) {
  searchMeasurements[label] = searchResult(
    label,
    Buffer.from(text, "ascii"),
    Buffer.from(query, "ascii"),
    cursor,
    routine,
    {
      carry: true,
      expectedCursor: cursor,
      expectedStatus,
    },
  );
}

searchMeasurements.fromEof = searchResult(
  "fromEof",
  Buffer.from("ABC", "ascii"),
  Buffer.from("A", "ascii"),
  3,
  "EditorSearchInitial",
  { expectedCursor: 0, expectedStatus: "EditorStatusWrapped" },
);

{
  const full = new Uint8Array(capacity).fill(0x41);
  searchMeasurements.fullMiss = searchResult(
    "fullMiss",
    full,
    Uint8Array.of(0x42),
    capacity >>> 1,
    "EditorSearchInitial",
    {
      carry: true,
      expectedCursor: capacity >>> 1,
      expectedStatus: "EditorStatusNotFound",
    },
  );
  full[capacity - 1] = 0x42;
  searchMeasurements.fullFinal = searchResult(
    "fullFinal",
    full,
    Uint8Array.of(0x42),
    0,
    "EditorSearchInitial",
    {
      expectedCursor: capacity - 1,
      expectedStatus: "EditorStatusFound",
    },
  );
}

{
  const machine = createMachine();
  prepareDefaultFcb(machine);
  installBuffer(machine, Buffer.from("ABC", "ascii"), 0);
  for (const [status, text] of [
    ["EditorStatusFound", "Found"],
    ["EditorStatusWrapped", "Wrapped"],
    ["EditorStatusNotFound", "Not found"],
    ["EditorStatusNoSearch", "No search"],
    ["EditorStatusReplaced", "Replaced"],
  ]) {
    machine.memory[symbol("EditorStatus")] = symbol(status);
    machine.bdos.terminal.reset();
    invokeRoutine(machine, "EditorRender");
    assert.ok(
      Buffer.from(machine.bdos.terminal.snapshot().cells.slice(23 * 80))
        .toString("ascii")
        .includes(text),
      `${status} is absent from the status row`,
    );
  }
  assertCanaries(machine);
}

// The position is derived from the rendered layout, not just the byte cursor.
// Keep multi-digit decimal output, 24-bit tab columns, and same-cursor document
// mutations covered because each exercises a different cache/formatter path.
function statusRow(machine) {
  return Buffer.from(machine.bdos.terminal.snapshot().cells.slice(23 * 80)).toString("ascii");
}
{
  const machine = createMachine();
  prepareDefaultFcb(machine);
  installBuffer(machine, Buffer.from("A".repeat(1233), "ascii"), 1233);
  invokeRoutine(machine, "EditorRender");
  assert.ok(statusRow(machine).includes("L1 C1234"));

  installBuffer(machine, new Uint8Array(8192).fill(9), 8192);
  invokeRoutine(machine, "EditorRender");
  assert.ok(statusRow(machine).includes("L1 C65537"));

  installBuffer(machine, Buffer.from("abc\nxyz", "ascii"), 3);
  invokeRoutine(machine, "EditorRender");
  assert.ok(statusRow(machine).includes("L1 C4"));
  machine.memory[symbol("EditorDma")] = 9;
  writeWord(machine.memory, symbol("EditorDocumentStart"), 0);
  writeWord(machine.memory, symbol("EditorDocumentRemove"), 1);
  writeWord(machine.memory, symbol("EditorDocumentInput"), symbol("EditorDma"));
  writeWord(machine.memory, symbol("EditorDocumentInsert"), 1);
  assert.equal(invokeRoutine(machine, "EditorDocumentSplice").carry, false);
  invokeRoutine(machine, "EditorPresent");
  assert.ok(statusRow(machine).includes("L1 C11"));
  assertCanaries(machine);
}

// A non-newline insertion before the viewport still shifts every later
// newline. The absolute top-line cache must be invalidated for this case too.
{
  const machine = createMachine();
  prepareDefaultFcb(machine);
  installBuffer(machine, Buffer.from("a\n".repeat(80), "ascii"), 120);
  invokeRoutine(machine, "EditorRender");
  assert.ok(statusRow(machine).includes("L61 C1"));
  machine.memory[symbol("EditorDma")] = 120;
  writeWord(machine.memory, symbol("EditorDocumentStart"), 0);
  writeWord(machine.memory, symbol("EditorDocumentRemove"), 0);
  writeWord(machine.memory, symbol("EditorDocumentInput"), symbol("EditorDma"));
  writeWord(machine.memory, symbol("EditorDocumentInsert"), 1);
  assert.equal(invokeRoutine(machine, "EditorDocumentSplice").carry, false);
  invokeRoutine(machine, "EditorPresent");
  assert.ok(statusRow(machine).includes("L60 C2"));
  assertCanaries(machine);
}

const replaceMeasurements = {};

function replacementPersistentSnapshot(machine) {
  return {
    state: machine.memory.slice(
      symbol("EditorLength"),
      symbol("EditorSaveState") + 1,
    ),
    text: machine.memory.slice(memoryLayout.textStart, machine.layout.textEnd),
  };
}

function compareReplacementFailure(before, machine) {
  const after = replacementPersistentSnapshot(machine);
  const statusOffset = symbol("EditorStatus") - symbol("EditorLength");
  after.state[statusOffset] = before.state[statusOffset];
  assert.deepEqual(after, before);
}

function replacementSuccess(
  label,
  text,
  query,
  cursor,
  input,
  expected,
  expectedCursor = cursor,
) {
  const machine = createMachine();
  installBuffer(machine, text, cursor);
  setQuery(machine, query, 0x63);
  machine.memory[symbol("EditorFlags")] =
    symbol("EditorFlagDesiredValid") | symbol("EditorFlagNew");
  writeWord(machine.memory, symbol("EditorTop"), 7);
  writeWord(machine.memory, symbol("EditorHorizontal"), 3);
  writeWord(machine.memory, symbol("EditorDesiredColumn"), 11);
  machine.memory[symbol("EditorSaveState")] = 0x5a;
  const beforeQuery = queryBlock(machine);
  machine.bdos.input.push(...input);
  const result = invokeRoutine(machine, "EditorReplaceBegin");
  assert.equal(result.carry, false, `${label}: replacement failed`);
  assert.deepEqual(bufferBytes(machine), Uint8Array.from(expected));
  assert.equal(
    readWord(machine.memory, symbol("EditorCursor")),
    expectedCursor,
  );
  assert.equal(readWord(machine.memory, symbol("EditorTop")), 7);
  assert.equal(readWord(machine.memory, symbol("EditorHorizontal")), 3);
  assert.equal(readWord(machine.memory, symbol("EditorDesiredColumn")), 11);
  assert.equal(machine.memory[symbol("EditorSaveState")], 0x5a);
  assert.deepEqual(queryBlock(machine), beforeQuery);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusReplaced"),
  );
  assert.notEqual(
    machine.memory[symbol("EditorFlags")] & symbol("EditorFlagDirty"),
    0,
  );
  assert.equal(
    machine.memory[symbol("EditorFlags")] & symbol("EditorFlagDesiredValid"),
    0,
  );
  assert.notEqual(
    machine.memory[symbol("EditorFlags")] & symbol("EditorFlagNew"),
    0,
  );
  assert.equal(machine.bdos.input.length, 0);
  assertCanaries(machine);
  return { machine, result };
}

for (const [label, text, query, cursor, status] of [
  ["noQuery", "ABC", "", 0, "EditorStatusNoSearch"],
  ["aheadOnly", "XABC", "ABC", 0, "EditorStatusNotFound"],
  ["partialEnd", "ABC", "BCD", 1, "EditorStatusNotFound"],
  ["crossLf", "A\nB", "AB", 0, "EditorStatusNotFound"],
  ["crossCrlf", "A\r\nB", "AB", 0, "EditorStatusNotFound"],
]) {
  const machine = createMachine();
  installBuffer(machine, Buffer.from(text, "ascii"), cursor);
  setQuery(machine, Buffer.from(query, "ascii"), 0x70);
  machine.memory[symbol("EditorFlags")] =
    symbol("EditorFlagDirty") |
    symbol("EditorFlagDesiredValid") |
    symbol("EditorFlagNew");
  writeWord(machine.memory, symbol("EditorTop"), 7);
  writeWord(machine.memory, symbol("EditorHorizontal"), 3);
  writeWord(machine.memory, symbol("EditorDesiredColumn"), 11);
  machine.memory[symbol("EditorSaveState")] = 0x5a;
  const before = replacementPersistentSnapshot(machine);
  replaceMeasurements[label] = invokeRoutine(machine, "EditorReplaceBegin");
  assert.equal(replaceMeasurements[label].carry, true, label);
  assert.equal(machine.memory[symbol("EditorStatus")], symbol(status), label);
  compareReplacementFailure(before, machine);
  assert.deepEqual(machine.bdos.events, []);
  assertCanaries(machine);
}

{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("ABC", "ascii"), 1);
  setQuery(machine, Buffer.from("B", "ascii"), 0x75);
  machine.memory[symbol("EditorFlags")] =
    symbol("EditorFlagDirty") |
    symbol("EditorFlagDesiredValid") |
    symbol("EditorFlagNew");
  writeWord(machine.memory, symbol("EditorTop"), 7);
  writeWord(machine.memory, symbol("EditorHorizontal"), 3);
  writeWord(machine.memory, symbol("EditorDesiredColumn"), 11);
  machine.memory[symbol("EditorStatus")] = symbol("EditorStatusSaved");
  machine.memory[symbol("EditorSaveState")] = 0x5a;
  const before = replacementPersistentSnapshot(machine);
  machine.bdos.input.push(27);
  replaceMeasurements.cancel = invokeRoutine(machine, "EditorReplaceBegin");
  assert.equal(replaceMeasurements.cancel.carry, false);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusReady"),
  );
  compareReplacementFailure(before, machine);
  assert.equal(machine.bdos.input.length, 0);
  assertCanaries(machine);
}

replaceMeasurements.grow = replacementSuccess(
  "grow",
  Buffer.from("ABC DEF", "ascii"),
  Buffer.from("C", "ascii"),
  2,
  [...Buffer.from("XYZ", "ascii"), 13],
  Buffer.from("ABXYZ DEF", "ascii"),
).result;
replaceMeasurements.shrink = replacementSuccess(
  "shrink",
  Buffer.from("0123456789", "ascii"),
  Buffer.from("3456", "ascii"),
  3,
  [...Buffer.from("Q", "ascii"), 13],
  Buffer.from("012Q789", "ascii"),
).result;
replaceMeasurements.equal = replacementSuccess(
  "equal and byte-identical",
  Buffer.from("SAME", "ascii"),
  Buffer.from("SAME", "ascii"),
  0,
  [...Buffer.from("SAME", "ascii"), 13],
  Buffer.from("SAME", "ascii"),
).result;
replaceMeasurements.delete = replacementSuccess(
  "delete final match",
  Buffer.from("STARTEND", "ascii"),
  Buffer.from("END", "ascii"),
  5,
  [13],
  Buffer.from("START", "ascii"),
).result;
replacementSuccess(
  "start boundary",
  Buffer.from("ONE TWO", "ascii"),
  Buffer.from("ONE", "ascii"),
  0,
  [...Buffer.from("1", "ascii"), 13],
  Buffer.from("1 TWO", "ascii"),
);
replacementSuccess(
  "end boundary",
  Buffer.from("ONE TWO", "ascii"),
  Buffer.from("TWO", "ascii"),
  4,
  [...Buffer.from("THREE", "ascii"), 13],
  Buffer.from("ONE THREE", "ascii"),
);
const tabReplacement = replacementSuccess(
  "tab and CRLF",
  Buffer.from("A\tB\r\nC\n", "ascii"),
  Buffer.from("B", "ascii"),
  2,
  [9, 13],
  Buffer.from("A\t\t\r\nC\n", "ascii"),
);
assert.ok(
  Buffer.from(
    tabReplacement.machine.bdos.terminal.snapshot().cells.slice(23 * 80),
  )
    .toString("ascii")
    .startsWith("Replace: >"),
);

{
  const bounded = replacementSuccess(
    "replacement literal capacity",
    Uint8Array.of(0x58),
    Uint8Array.of(0x58),
    0,
    [...new Uint8Array(64).fill(0x52), 0x5a, 13],
    new Uint8Array(64).fill(0x52),
  );
  assert.equal(bounded.machine.bdos.terminal.snapshot().bellCount, 1);
}
{
  const machine = createMachine();
  installBuffer(machine, Uint8Array.of(0x58), 0);
  setQuery(machine, Uint8Array.of(0x58));
  machine.bdos.input.push(8, 127, 2, 0x59, 13);
  replaceMeasurements.controls = invokeRoutine(machine, "EditorReplaceBegin");
  assert.equal(replaceMeasurements.controls.carry, false);
  assert.deepEqual(bufferBytes(machine), Uint8Array.of(0x59));
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 3);
  assertCanaries(machine);
}

{
  const text = new Uint8Array(capacity - 1).fill(0x41);
  const expected = new Uint8Array(capacity).fill(0x41);
  expected[capacity - 2] = 0x42;
  expected[capacity - 1] = 0x42;
  replaceMeasurements.exactCapacity = replacementSuccess(
    "exact text capacity",
    text,
    Uint8Array.of(0x41),
    capacity - 2,
    [0x42, 0x42, 13],
    expected,
  ).result;
}
{
  const machine = createMachine();
  installBuffer(machine, new Uint8Array(capacity).fill(0x41), capacity - 1);
  setQuery(machine, Uint8Array.of(0x41), 0x79);
  machine.memory[symbol("EditorFlags")] =
    symbol("EditorFlagDirty") |
    symbol("EditorFlagDesiredValid") |
    symbol("EditorFlagNew");
  writeWord(machine.memory, symbol("EditorTop"), 7);
  writeWord(machine.memory, symbol("EditorHorizontal"), 3);
  writeWord(machine.memory, symbol("EditorDesiredColumn"), 11);
  machine.memory[symbol("EditorSaveState")] = 0x5a;
  const before = replacementPersistentSnapshot(machine);
  machine.bdos.input.push(0x42, 0x42, 13);
  replaceMeasurements.rejectedGrowth = invokeRoutine(
    machine,
    "EditorReplaceBegin",
  );
  assert.equal(replaceMeasurements.rejectedGrowth.carry, true);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusFull"),
  );
  compareReplacementFailure(before, machine);
  assertCanaries(machine);
}

{
  const first = replacementSuccess(
    "repeated first",
    Buffer.from("ONE ONE", "ascii"),
    Buffer.from("ONE", "ascii"),
    0,
    [...Buffer.from("TWO", "ascii"), 13],
    Buffer.from("TWO ONE", "ascii"),
  );
  replaceMeasurements.repeatSearch = invokeRoutine(
    first.machine,
    "EditorSearchRepeat",
  );
  assert.equal(replaceMeasurements.repeatSearch.carry, false);
  assert.equal(readWord(first.machine.memory, symbol("EditorCursor")), 4);
  first.machine.bdos.input.push(0x58, 13);
  replaceMeasurements.repeated = invokeRoutine(
    first.machine,
    "EditorReplaceBegin",
  );
  assert.equal(replaceMeasurements.repeated.carry, false);
  assert.deepEqual(
    bufferBytes(first.machine),
    Uint8Array.from(Buffer.from("TWO X", "ascii")),
  );
  assert.equal(readWord(first.machine.memory, symbol("EditorCursor")), 4);
  assertCanaries(first.machine);
}
{
  const overlap = replacementSuccess(
    "overlapping candidates",
    Buffer.from("AAA", "ascii"),
    Buffer.from("AA", "ascii"),
    0,
    [0x58, 13],
    Buffer.from("XA", "ascii"),
  );
  replaceMeasurements.overlapRepeat = invokeRoutine(
    overlap.machine,
    "EditorSearchRepeat",
  );
  assert.equal(replaceMeasurements.overlapRepeat.carry, true);
  assert.equal(readWord(overlap.machine.memory, symbol("EditorCursor")), 0);
  assert.equal(
    overlap.machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusNotFound"),
  );
  assertCanaries(overlap.machine);
}
{
  const machine = createMachine();
  installBuffer(machine, Buffer.from("ABC", "ascii"), 1);
  setQuery(machine, Buffer.from("B", "ascii"));
  const inserted = invokeRoutine(machine, "EditorBufferInsertByte", {
    registers: { a: 0x58 },
  });
  assert.equal(inserted.carry, false);
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("AXBC", "ascii")),
  );
  assert.deepEqual(queryBytes(machine), Uint8Array.of(0x42));
  searchMeasurements.afterEdit = invokeRoutine(machine, "EditorSearchRepeat");
  assert.equal(searchMeasurements.afterEdit.carry, false);
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 2);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusWrapped"),
  );
  assertCanaries(machine);
}
{
  const machine = createMachine();
  installBuffer(
    machine,
    Buffer.from("1234567890\r\nx\r\nabcdefghij", "ascii"),
    8,
  );
  navigationMeasurements.downShort = invokeRoutine(machine, "EditorMoveDown");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 13);
  navigationMeasurements.downRetained = invokeRoutine(
    machine,
    "EditorMoveDown",
  );
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 23);
  navigationMeasurements.upRetained = invokeRoutine(machine, "EditorMoveUp");
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 13);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  prepareDefaultFcb(machine);
  installBuffer(machine, Buffer.from("A\tB\r\n", "ascii"), 2);
  navigationMeasurements.tabRender = invokeRoutine(machine, "EditorRender");
  const snapshot = machine.bdos.terminal.snapshot();
  assert.equal(
    Buffer.from(snapshot.cells.slice(0, 80)).toString("ascii"),
    "A       B".padEnd(80),
  );
  assert.equal(snapshot.cursorRow, 0);
  assert.equal(snapshot.cursorColumn, 8);
  const statusAttributes = snapshot.attributes.slice(23 * 80);
  assert.ok(
    statusAttributes.every(
      (attribute) => attribute === CPM22_TERMINAL_ATTR_REVERSE,
    ),
    `unexpected status attributes ${JSON.stringify([...new Set(statusAttributes)])}`,
  );
  assertCanaries(machine);
}
{
  const machine = createMachine();
  prepareDefaultFcb(machine);
  installBuffer(machine, new Uint8Array(90).fill(0x41), 85);
  navigationMeasurements.horizontalScroll = invokeRoutine(
    machine,
    "EditorRender",
  );
  assert.equal(readWord(machine.memory, symbol("EditorHorizontal")), 6);
  assert.equal(machine.bdos.terminal.snapshot().cursorColumn, 79);
  assertCanaries(machine);
}
{
  const machine = createMachine();
  prepareDefaultFcb(machine);
  const lines = Buffer.from(
    `${Array.from({ length: 25 }, (_, index) => `L${index}`).join("\r\n")}\r\n`,
  );
  const line24 = Buffer.from(
    `${Array.from({ length: 24 }, (_, index) => `L${index}`).join("\r\n")}\r\n`,
  ).length;
  installBuffer(machine, lines, line24);
  navigationMeasurements.verticalScroll = invokeRoutine(
    machine,
    "EditorRender",
  );
  assert.equal(machine.bdos.terminal.snapshot().cursorRow, 22);
  assert.equal(
    Buffer.from(machine.bdos.terminal.snapshot().cells.slice(0, 80)).toString(
      "ascii",
    ),
    "L2".padEnd(80),
  );
  assertCanaries(machine);
}

function prepareSaveMachine(
  content,
  { old = Buffer.from("OLD\r\n"), failures = [], files = {} } = {},
) {
  const machine = createMachine({
    files: { "INPUT.NU": physicalFile(old), ...files },
    failures,
  });
  prepareDefaultFcb(machine);
  installBuffer(machine, content, 0);
  machine.memory[symbol("EditorFlags")] = symbol("EditorFlagDirty");
  return machine;
}

function assertSuccessfulSave(machine, content) {
  assert.deepEqual(machine.bdos.files.get("INPUT.NU"), physicalFile(content));
  assert.equal(machine.bdos.files.has("INPUT.$$$"), false);
  assert.equal(machine.bdos.files.has("INPUT.BAK"), false);
  assert.equal(
    machine.memory[symbol("EditorFlags")] & symbol("EditorFlagDirty"),
    0,
  );
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusSaved"),
  );
  assert.deepEqual(bufferBytes(machine), Uint8Array.from(content));
  assertUnusedTextCanary(machine);
  assertCanaries(machine);
}

function prepareNewSaveMachine(
  content,
  { filename = "NEW.NU", files = {}, failures = [] } = {},
) {
  const machine = createMachine({ files, failures });
  setCommandTail(machine.memory, filename);
  assert.equal(invokeRoutine(machine, "EditorPrepareCommand").carry, false);
  const load = invokeRoutine(machine, "EditorLoadFile");
  assert.equal(load.carry, false, `${filename} did not open as a new buffer`);
  installBuffer(machine, content, 0);
  machine.memory[symbol("EditorFlags")] =
    symbol("EditorFlagDirty") | symbol("EditorFlagNew");
  return machine;
}

function assertSuccessfulNewSave(machine, filename, content) {
  const stem = filename.slice(0, filename.lastIndexOf("."));
  assert.deepEqual(machine.bdos.files.get(filename), physicalFile(content));
  assert.equal(machine.bdos.files.has(`${stem}.$$$`), false);
  assert.equal(machine.bdos.files.has(`${stem}.BAK`), false);
  assert.equal(
    machine.memory[symbol("EditorFlags")] &
      (symbol("EditorFlagDirty") |
        symbol("EditorFlagConfirmQuit") |
        symbol("EditorFlagNew")),
    0,
  );
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusSaved"),
  );
  assert.deepEqual(bufferBytes(machine), Uint8Array.from(content));
  assertUnusedTextCanary(machine);
  assertCanaries(machine);
}

const saveMeasurements = {};
const newFileMeasurements = {};
{
  const content = Buffer.from("NEW\r\n", "ascii");
  const machine = prepareSaveMachine(content);
  setQuery(machine, Buffer.from("NEW", "ascii"), 0x60);
  const beforeQuery = queryBlock(machine);
  saveMeasurements.success = invokeRoutine(machine, "EditorSave");
  assert.equal(saveMeasurements.success.carry, false);
  assertSuccessfulSave(machine, content);
  assert.deepEqual(queryBlock(machine), beforeQuery);
  searchMeasurements.afterSave = invokeRoutine(machine, "EditorSearchInitial");
  assert.equal(searchMeasurements.afterSave.carry, false);
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 0);
  assert.deepEqual(queryBlock(machine), beforeQuery);
}
for (const [label, content] of [
  ["empty", new Uint8Array()],
  ["exactRecord", new Uint8Array(128).fill(0x41)],
  ["partialRecord", new Uint8Array(129).fill(0x42)],
]) {
  const machine = prepareSaveMachine(content);
  saveMeasurements[label] = invokeRoutine(machine, "EditorSave");
  assert.equal(saveMeasurements[label].carry, false);
  assertSuccessfulSave(machine, content);
}
for (const [label, filename] of [
  ["temporaryConflict", "INPUT.$$$"],
  ["backupConflict", "INPUT.BAK"],
]) {
  const reserved = Uint8Array.of(0xaa);
  const machine = prepareSaveMachine(Buffer.from("NEW", "ascii"), {
    files: { [filename]: reserved },
  });
  const before = machine.bdos.files.get("INPUT.NU");
  const result = invokeRoutine(machine, "EditorSave");
  assert.equal(result.carry, true);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusSaveConflict"),
  );
  assert.deepEqual(machine.bdos.files.get("INPUT.NU"), before);
  assert.deepEqual(machine.bdos.files.get(filename), reserved);
  saveMeasurements[label] = result;
}

const saveFailures = [
  ["create", "make:INPUT.$$$", "EditorStatusSaveCreate"],
  ["write", "write:INPUT.$$$", "EditorStatusSaveWrite"],
  ["close", "close:INPUT.$$$", "EditorStatusSaveClose"],
  ["renameOld", "rename:INPUT.NU->INPUT.BAK", "EditorStatusSaveRename"],
  ["renameNew", "rename:INPUT.$$$->INPUT.NU", "EditorStatusSaveRename"],
  ["deleteBackup", "delete:INPUT.BAK", "EditorStatusSaveRename"],
];
for (const [label, failure, expectedStatus] of saveFailures) {
  const old = physicalFile(Buffer.from("OLD\r\n", "ascii"));
  const machine = prepareSaveMachine(Buffer.from("NEW\r\n", "ascii"), {
    failures: [failure],
  });
  const result = invokeRoutine(machine, "EditorSave");
  assert.equal(result.carry, true, `${label} failure reported success`);
  assert.equal(machine.memory[symbol("EditorStatus")], symbol(expectedStatus));
  assert.deepEqual(machine.bdos.files.get("INPUT.NU"), old);
  assert.equal(machine.bdos.files.has("INPUT.$$$"), false);
  assert.equal(machine.bdos.files.has("INPUT.BAK"), false);
  assert.notEqual(
    machine.memory[symbol("EditorFlags")] & symbol("EditorFlagDirty"),
    0,
  );
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("NEW\r\n", "ascii")),
  );
  assertCanaries(machine);
  saveMeasurements[label] = result;
  if (label === "write") {
    machine.bdos.terminal.reset();
    invokeRoutine(machine, "EditorRender");
    const statusRow = Buffer.from(
      machine.bdos.terminal.snapshot().cells.slice(23 * 80),
    ).toString("ascii");
    assert.ok(statusRow.includes("Save failed 12"));
  }
}
{
  const old = physicalFile(Buffer.from("OLD\r\n", "ascii"));
  const machine = prepareSaveMachine(Buffer.from("NEW\r\n", "ascii"), {
    failures: ["rename:INPUT.$$$->INPUT.NU", "rename:INPUT.BAK->INPUT.NU"],
  });
  saveMeasurements.rollbackFailure = invokeRoutine(machine, "EditorSave");
  assert.equal(saveMeasurements.rollbackFailure.carry, true);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusSaveRollback"),
  );
  assert.equal(machine.bdos.files.has("INPUT.NU"), false);
  assert.deepEqual(machine.bdos.files.get("INPUT.BAK"), old);
  assert.equal(machine.bdos.files.has("INPUT.$$$"), false);
  assertCanaries(machine);
}
{
  const content = Buffer.from("RETRY\r\n", "ascii");
  const machine = prepareSaveMachine(content, {
    failures: ["write:INPUT.$$$"],
  });
  assert.equal(invokeRoutine(machine, "EditorSave").carry, true);
  saveMeasurements.retry = invokeRoutine(machine, "EditorSave");
  assert.equal(saveMeasurements.retry.carry, false);
  assertSuccessfulSave(machine, content);
}
{
  const first = Buffer.from("FIRST\r\n", "ascii");
  const second = Buffer.from("SECOND\r\n", "ascii");
  const machine = prepareSaveMachine(first);
  assert.equal(invokeRoutine(machine, "EditorSave").carry, false);
  installBuffer(machine, second, 0);
  machine.memory[symbol("EditorFlags")] = symbol("EditorFlagDirty");
  saveMeasurements.repeated = invokeRoutine(machine, "EditorSave");
  assert.equal(saveMeasurements.repeated.carry, false);
  assertSuccessfulSave(machine, second);
}

for (const [label, content] of [
  ["empty", new Uint8Array()],
  ["partialRecord", Buffer.from("NEW", "ascii")],
  ["exactRecord", new Uint8Array(128).fill(0x45)],
  ["maximum", new Uint8Array(capacity).fill(0x4d)],
]) {
  const machine = prepareNewSaveMachine(content);
  setQuery(machine, Buffer.from("Q", "ascii"), 0x60);
  const queryBefore = queryBlock(machine);
  newFileMeasurements[`save${label}`] = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements[`save${label}`].carry, false);
  assertSuccessfulNewSave(machine, "NEW.NU", content);
  assert.deepEqual(queryBlock(machine), queryBefore);
}

for (const [label, reservedName] of [
  ["temporaryConflict", "NEW.$$$"],
  ["backupConflict", "NEW.BAK"],
]) {
  const reserved = Uint8Array.of(0xaa);
  const machine = prepareNewSaveMachine(Buffer.from("NEW", "ascii"), {
    files: { [reservedName]: reserved },
  });
  newFileMeasurements[label] = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements[label].carry, true);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusSaveConflict"),
  );
  assert.equal(machine.bdos.files.has("NEW.NU"), false);
  assert.deepEqual(machine.bdos.files.get(reservedName), reserved);
  assert.equal(
    machine.memory[symbol("EditorFlags")],
    symbol("EditorFlagDirty") | symbol("EditorFlagNew"),
  );
  machine.bdos.files.delete(reservedName);
  newFileMeasurements[`${label}Retry`] = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements[`${label}Retry`].carry, false);
  assertSuccessfulNewSave(machine, "NEW.NU", Buffer.from("NEW", "ascii"));
}

for (const [label, failures, expectedStatus, retainedTemporary] of [
  ["create", ["make:NEW.$$$"], "EditorStatusSaveCreate", false],
  ["write", ["write:NEW.$$$"], "EditorStatusSaveWrite", false],
  ["close", ["close:NEW.$$$"], "EditorStatusSaveClose", false],
  ["install", ["rename:NEW.$$$->NEW.NU"], "EditorStatusSaveRename", false],
  [
    "rollbackClose",
    ["write:NEW.$$$", "close:NEW.$$$"],
    "EditorStatusSaveWrite",
    false,
  ],
  [
    "rollbackDelete",
    ["write:NEW.$$$", "delete:NEW.$$$"],
    "EditorStatusSaveWrite",
    true,
  ],
]) {
  const content = Buffer.from("RETRY", "ascii");
  const machine = prepareNewSaveMachine(content, { failures });
  newFileMeasurements[label] = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements[label].carry, true, `${label} succeeded`);
  assert.equal(machine.memory[symbol("EditorStatus")], symbol(expectedStatus));
  assert.equal(machine.bdos.files.has("NEW.NU"), false);
  assert.equal(machine.bdos.files.has("NEW.BAK"), false);
  assert.equal(machine.bdos.files.has("NEW.$$$"), retainedTemporary);
  assert.equal(
    machine.memory[symbol("EditorFlags")],
    symbol("EditorFlagDirty") | symbol("EditorFlagNew"),
  );
  if (retainedTemporary) machine.bdos.files.delete("NEW.$$$");
  newFileMeasurements[`${label}Retry`] = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements[`${label}Retry`].carry, false);
  assertSuccessfulNewSave(machine, "NEW.NU", content);
}

{
  const content = Buffer.from("FIRST", "ascii");
  const machine = prepareNewSaveMachine(content);
  newFileMeasurements.firstSave = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements.firstSave.carry, false);
  assertSuccessfulNewSave(machine, "NEW.NU", content);
  installBuffer(machine, Buffer.from("SECOND", "ascii"), 0);
  machine.memory[symbol("EditorFlags")] = symbol("EditorFlagDirty");
  const eventStart = machine.bdos.events.length;
  newFileMeasurements.ordinaryAfterFirst = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements.ordinaryAfterFirst.carry, false);
  assertSuccessfulNewSave(machine, "NEW.NU", Buffer.from("SECOND", "ascii"));
  assert.ok(
    machine.bdos.events.slice(eventStart).includes("rename:NEW.NU->NEW.BAK"),
  );
}

{
  const prior = physicalFile(Buffer.from("OTHER", "ascii"));
  const machine = prepareNewSaveMachine(Buffer.from("OURS", "ascii"));
  machine.bdos.files.set("NEW.NU", prior);
  newFileMeasurements.unexpectedTarget = invokeRoutine(machine, "EditorSave");
  assert.equal(newFileMeasurements.unexpectedTarget.carry, true);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusSaveRename"),
  );
  assert.deepEqual(machine.bdos.files.get("NEW.NU"), prior);
  assert.equal(machine.bdos.files.has("NEW.$$$"), false);
  assert.equal(machine.bdos.files.has("NEW.BAK"), false);
  assert.equal(
    machine.memory[symbol("EditorFlags")],
    symbol("EditorFlagDirty") | symbol("EditorFlagNew"),
  );
}

function runEditorInput(input, file = Buffer.from("A\r\n", "ascii")) {
  const machine = createMachine({ files: { "INPUT.NU": physicalFile(file) } });
  setCommandTail(machine.memory, "INPUT.NU");
  machine.bdos.input.push(...input);
  let highBefore;
  const result = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
    beforeRun() {
      highBefore = machine.memory.slice(machine.layout.top, 0x10000);
    },
  });
  assert.deepEqual(
    machine.memory.slice(machine.layout.top, 0x10000),
    highBefore,
    "EditorEntry changed CP/M high memory",
  );
  assert.ok(result.stackBytes > 0 && result.stackBytes <= 32);
  assertCanaries(machine, { high: false });
  return { machine, result };
}

function runNewEditorInput(input, failures = []) {
  const machine = createMachine({ failures });
  setCommandTail(machine.memory, "NEW.NU");
  machine.bdos.input.push(...input);
  let highBefore;
  const result = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
    beforeRun() {
      highBefore = machine.memory.slice(machine.layout.top, 0x10000);
    },
  });
  assert.deepEqual(machine.memory.slice(machine.layout.top), highBefore);
  assert.ok(result.stackBytes > 0 && result.stackBytes <= 32);
  assertCanaries(machine, { high: false });
  return { machine, result };
}

const entryMeasurements = {};
{
  const { machine, result } = runNewEditorInput([0x11, 0x11]);
  entryMeasurements.newUntouchedDiscard = result;
  assert.equal(machine.bdos.files.has("NEW.NU"), false);
  assert.equal(machine.bdos.files.has("NEW.$$$"), false);
  assert.equal(machine.bdos.files.has("NEW.BAK"), false);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runNewEditorInput([0x58, 0x11, 0x11]);
  entryMeasurements.newEditedDiscard = result;
  assert.deepEqual(bufferBytes(machine), Uint8Array.of(0x58));
  assert.equal(machine.bdos.files.has("NEW.NU"), false);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runNewEditorInput([19, 0x11]);
  entryMeasurements.newEmptySaveQuit = result;
  assert.deepEqual(machine.bdos.files.get("NEW.NU"), new Uint8Array());
  assert.equal(
    machine.memory[symbol("EditorFlags")] &
      (symbol("EditorFlagDirty") | symbol("EditorFlagNew")),
    0,
  );
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runNewEditorInput([0x58, 19, 0x11]);
  entryMeasurements.newEditedSaveQuit = result;
  assert.deepEqual(
    logicalFileBytes(machine.bdos.files.get("NEW.NU")),
    Uint8Array.of(0x58),
  );
  assert.equal(
    machine.memory[symbol("EditorFlags")] &
      (symbol("EditorFlagDirty") | symbol("EditorFlagNew")),
    0,
  );
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runNewEditorInput(
    [0x58, 19, 19, 0x11],
    ["write:NEW.$$$"],
  );
  entryMeasurements.newFailureRetryQuit = result;
  assert.deepEqual(
    logicalFileBytes(machine.bdos.files.get("NEW.NU")),
    Uint8Array.of(0x58),
  );
  assert.equal(
    machine.memory[symbol("EditorFlags")] &
      (symbol("EditorFlagDirty") | symbol("EditorFlagNew")),
    0,
  );
  assert.equal(machine.bdos.input.length, 0);
}
{
  const machine = createMachine();
  setCommandTail(machine.memory, "NEW.NU");
  machine.bdos.input.push(0x11, 0x11);
  entryMeasurements.sequenceDiscard = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
  });
  assert.equal(machine.bdos.files.has("NEW.NU"), false);

  // Bare EDIT starts an unnamed buffer. ^S asks for a name: Escape leaves it
  // unnamed without touching a file or ringing, and ^Q then leaves at once
  // because nothing was typed.
  const bare = (keys) => {
    machine.bdos.terminal.reset();
    setCommandTail(machine.memory, "");
    const before = machine.bdos.events.length;
    machine.bdos.input.push(...keys);
    const result = invokeRoutine(machine, "EditorEntry", { callerSp: ENTRY_CALLER_SP });
    assert.ok(!Buffer.from(machine.bdos.terminal.snapshot().cells).toString("ascii").includes("EDIT error"));
    assert.equal(machine.bdos.input.length, 0);
    return { result, events: machine.bdos.events.slice(before), bells: machine.bdos.terminal.snapshot().bellCount };
  };
  const ascii = (text) => [...Buffer.from(text, "ascii")];
  const cancelled = bare([19, 27, 0x11]);
  entryMeasurements.sequenceBareMissing = cancelled.result;
  assert.deepEqual(cancelled.events, []);
  assert.equal(cancelled.bells, 0);
  // A name that is not valid rings and stays unnamed; ^Q twice discards.
  const invalid = bare([...ascii("AB"), 19, ...ascii("*.NU"), 13, 0x11, 0x11]);
  assert.deepEqual(invalid.events, []);
  assert.equal(invalid.bells, 1);
  // A valid name saves the buffer as a new file under it.
  const named = bare([...ascii("AB"), 19, ...ascii(" saved.nu "), 13, 0x11]);
  assert.ok(named.events.some((event) => event.includes("SAVED.NU")), named.events.join(" "));
  assert.deepEqual(logicalFileBytes(machine.bdos.files.get("SAVED.NU")), Uint8Array.from(ascii("AB")));

  machine.bdos.terminal.reset();
  setCommandTail(machine.memory, "NEW.NU");
  machine.bdos.input.push(19, 0x11);
  entryMeasurements.sequenceCreate = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
  });
  assert.deepEqual(machine.bdos.files.get("NEW.NU"), new Uint8Array());

  machine.bdos.terminal.reset();
  setQuery(machine, Buffer.from("STALE", "ascii"));
  setCommandTail(machine.memory, "NEW.NU");
  machine.bdos.input.push(0x11);
  entryMeasurements.sequenceExisting = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
  });
  assert.equal(machine.memory[symbol("EditorFlags")], 0);
  assert.equal(machine.memory[symbol("EditorQueryLength")], 0);
  assert.equal(machine.bdos.input.length, 0);
  assertCanaries(machine, { high: false });
}
{
  const { machine, result } = runEditorInput([0x11]);
  entryMeasurements.cleanQuit = result;
  assert.deepEqual(
    machine.bdos.files.get("INPUT.NU"),
    physicalFile(Buffer.from("A\r\n")),
  );
}
{
  const { machine, result } = runEditorInput([
    0x58, 0x11, 0x1b, 0x5b, 0x44, 0x11, 0x11,
  ]);
  entryMeasurements.discard = result;
  assert.deepEqual(
    machine.bdos.files.get("INPUT.NU"),
    physicalFile(Buffer.from("A\r\n")),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 0);
}
{
  const { machine, result } = runEditorInput([0x1b, 0x58, 0x11]);
  entryMeasurements.badEscape = result;
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
}
{
  const { machine, result } = runEditorInput([
    0x1b,
    ...new Array(256).fill(0),
    0x11,
  ]);
  entryMeasurements.escapeTimeout = result;
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
}
{
  const { machine, result } = runEditorInput(
    [0x1b, 0x5b, 0x44, 0x7f, 0x1b, 0x5b, 0x41, 0x11],
    new Uint8Array(),
  );
  entryMeasurements.boundaries = result;
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 3);
}
{
  const { machine, result } = runEditorInput(
    [6, 0x41, 0x42, 0x41, 13, 14, 0x11],
    Buffer.from("ABABA\r\n", "ascii"),
  );
  entryMeasurements.searchRepeat = result;
  assert.deepEqual(
    queryBytes(machine),
    Uint8Array.from(Buffer.from("ABA", "ascii")),
  );
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 2);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusFound"),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 0);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [6, 0x5a, 13, 0x11],
    Buffer.from("ABC\r\n", "ascii"),
  );
  entryMeasurements.searchMissing = result;
  assert.deepEqual(queryBytes(machine), Uint8Array.of(0x5a));
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 0);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusNotFound"),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [14, 0x11],
    Buffer.from("ABC\r\n", "ascii"),
  );
  entryMeasurements.searchNoQuery = result;
  assert.equal(machine.memory[symbol("EditorQueryLength")], 0);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusNoSearch"),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [
      6,
      ...Buffer.from("ONE", "ascii"),
      13,
      18,
      ...Buffer.from("TWO", "ascii"),
      13,
      19,
      0x11,
    ],
    Buffer.from("ONE ONE\r\n", "ascii"),
  );
  entryMeasurements.replaceSave = result;
  assert.deepEqual(
    logicalFileBytes(machine.bdos.files.get("INPUT.NU")),
    Uint8Array.from(Buffer.from("TWO ONE\r\n", "ascii")),
  );
  assert.deepEqual(
    queryBytes(machine),
    Uint8Array.from(Buffer.from("ONE", "ascii")),
  );
  assert.equal(machine.bdos.input.length, 0);

  machine.bdos.terminal.reset();
  setCommandTail(machine.memory, "INPUT.NU");
  machine.bdos.input.push(0x11);
  entryMeasurements.replaceReload = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
  });
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("TWO ONE\r\n", "ascii")),
  );
  assert.equal(machine.memory[symbol("EditorQueryLength")], 0);
  assert.equal(machine.bdos.input.length, 0);
  assertCanaries(machine, { high: false });
}
{
  const { machine, result } = runEditorInput(
    [18, 0x11],
    Buffer.from("ABC\r\n", "ascii"),
  );
  entryMeasurements.replaceNoQuery = result;
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusNoSearch"),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [6, 0x5a, 13, 18, 0x11],
    Buffer.from("ABC\r\n", "ascii"),
  );
  entryMeasurements.replaceMismatch = result;
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusNotFound"),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 2);
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("ABC\r\n", "ascii")),
  );
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [6, 0x41, 13, 18, 27, 0x11],
    Buffer.from("ABC\r\n", "ascii"),
  );
  entryMeasurements.replaceCancel = result;
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("ABC\r\n", "ascii")),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 0);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [0x58, 0x11, 18, 0x11, 0x11],
    Buffer.from("A\r\n", "ascii"),
  );
  entryMeasurements.replaceCancelsDiscard = result;
  assert.deepEqual(
    machine.bdos.files.get("INPUT.NU"),
    physicalFile(Buffer.from("A\r\n", "ascii")),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [
      6,
      ...Buffer.from("ONE", "ascii"),
      13,
      18,
      ...Buffer.from("TWO", "ascii"),
      13,
      14,
      0x11,
      0x11,
    ],
    Buffer.from("ONE ONE", "ascii"),
  );
  entryMeasurements.replaceThenRepeat = result;
  assert.deepEqual(
    bufferBytes(machine),
    Uint8Array.from(Buffer.from("TWO ONE", "ascii")),
  );
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 4);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runNewEditorInput([
    0x41, 6, 0x41, 13, 18, 0x42, 13, 19, 0x11,
  ]);
  entryMeasurements.newReplaceSave = result;
  assert.deepEqual(
    logicalFileBytes(machine.bdos.files.get("NEW.NU")),
    Uint8Array.of(0x42),
  );
  assert.equal(
    machine.memory[symbol("EditorFlags")] &
      (symbol("EditorFlagDirty") | symbol("EditorFlagNew")),
    0,
  );
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [0x58, 0x11, 6, 27, 0x11, 0x11],
    Buffer.from("A\r\n", "ascii"),
  );
  entryMeasurements.searchCancelsDiscard = result;
  assert.deepEqual(
    machine.bdos.files.get("INPUT.NU"),
    physicalFile(Buffer.from("A\r\n", "ascii")),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 0);
  assert.equal(machine.bdos.input.length, 0);
}
{
  const { machine, result } = runEditorInput(
    [0x58, 6, 0x41, 13, 19, 14, 0x11],
    Buffer.from("ABA\r\n", "ascii"),
  );
  entryMeasurements.searchSaveRepeat = result;
  assert.deepEqual(
    logicalFileBytes(machine.bdos.files.get("INPUT.NU")),
    Uint8Array.from(Buffer.from("XABA\r\n", "ascii")),
  );
  assert.deepEqual(queryBytes(machine), Uint8Array.of(0x41));
  assert.equal(readWord(machine.memory, symbol("EditorCursor")), 3);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusFound"),
  );
  assert.equal(machine.bdos.input.length, 0);
}
{
  const machine = createMachine({
    files: { "INPUT.NU": physicalFile(Buffer.from("ABC\r\n", "ascii")) },
  });
  setCommandTail(machine.memory, "INPUT.NU");
  machine.bdos.input.push(6, 0x42, 13, 0x11);
  entryMeasurements.firstExecutionSearch = invokeRoutine(
    machine,
    "EditorEntry",
    { callerSp: ENTRY_CALLER_SP },
  );
  assert.deepEqual(queryBytes(machine), Uint8Array.of(0x42));
  machine.bdos.terminal.reset();
  machine.bdos.input.push(14, 0x11);
  entryMeasurements.secondExecutionReset = invokeRoutine(
    machine,
    "EditorEntry",
    { callerSp: ENTRY_CALLER_SP },
  );
  assert.equal(machine.memory[symbol("EditorQueryLength")], 0);
  assert.equal(
    machine.memory[symbol("EditorStatus")],
    symbol("EditorStatusNoSearch"),
  );
  assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
  assert.equal(machine.bdos.input.length, 0);
  assertCanaries(machine, { high: false });
}
{
  const machine = createMachine();
  setCommandTail(machine.memory, "*.NU");
  let highBefore;
  const result = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
    beforeRun() {
      highBefore = machine.memory.slice(machine.layout.top, 0x10000);
    },
  });
  assert.deepEqual(machine.memory.slice(machine.layout.top), highBefore);
  assert.ok(
    Buffer.from(machine.bdos.terminal.snapshot().cells)
      .toString("ascii")
      .includes("EDIT error 01"),
  );
  entryMeasurements.missing = result;
}

// Configuration block, screen-size selection, and the memory partition
// derived from the BDOS address.
const configurationMeasurements = {};
{
  assert.equal(symbol("EditorConfig"), 0x0103);
  assert.equal(symbol("EditorConfigColumns"), 0x0108);
  assert.equal(symbol("EditorConfigRows"), 0x0109);
  assert.equal(symbol("EditorConfigFlags"), 0x010a);
  assert.deepEqual(readConfiguration(binary.bytes), {
    columns: 80,
    rows: 24,
    probe: true,
  });
  const configured = configureImage(binary.bytes, {
    columns: 40,
    rows: 16,
    probe: false,
  });
  assert.deepEqual(readConfiguration(configured), {
    columns: 40,
    rows: 16,
    probe: false,
  });
  assert.deepEqual(configured.slice(0, 8), binary.bytes.slice(0, 8));
  assert.deepEqual(configured.slice(11), binary.bytes.slice(11));
  assert.deepEqual(
    readConfiguration(configureImage(configured, { probe: true })),
    { columns: 40, rows: 16, probe: true },
  );
  for (const options of [
    { columns: 19 },
    { columns: 81 },
    { rows: 3 },
    { rows: 25 },
    { columns: 40.5 },
  ]) {
    assert.throws(() => configureImage(binary.bytes, options));
  }
  assert.throws(() => readConfiguration(binary.bytes.slice(1)));
}

function selectScreen({ config, flags, abi, legacyAbi } = {}) {
  const machine = createMachine();
  const memory = machine.memory;
  memory[symbol("EditorColumns")] = 0;
  memory[symbol("EditorTextRows")] = 0;
  if (config !== undefined) {
    memory[symbol("EditorConfigColumns")] = config[0];
    memory[symbol("EditorConfigRows")] = config[1];
  }
  if (flags !== undefined) memory[symbol("EditorConfigFlags")] = flags;
  if (legacyAbi) {
    memory.set(Buffer.from("TNA", "ascii"), 0xff00);
    writeWord(memory, 0xff09, 0xff40);
    memory.set([21, 8], 0xff40);
  }
  if (abi !== undefined) {
    memory.set(Buffer.from(abi.tag ?? "TNA", "ascii"), 0xc003);
    const pointer = abi.pointer ?? 0xc040;
    memory[0xc006] = abi.major ?? 3;
    writeWord(memory, 0xc008, pointer);
    if (pointer !== 0) memory.set(abi.size, pointer);
  }
  const before = memory.slice();
  const result = invokeRoutine(machine, "EditorSelectScreen");
  const changed = [];
  for (let address = 0; address < 0x10000; address += 1) {
    const stack =
      address >= machine.layout.top - memoryLayout.stackSize &&
      address < machine.layout.top;
    if (!stack && memory[address] !== before[address]) changed.push(address);
  }
  for (const address of changed) {
    assert.ok(
      address === symbol("EditorColumns") ||
        address === symbol("EditorTextRows") ||
        address === symbol("TRMICH"),
      `EditorSelectScreen wrote ${address.toString(16)}`,
    );
  }
  return {
    size: [memory[symbol("EditorColumns")], memory[symbol("EditorTextRows")] + 1],
    result,
  };
}

for (const [options, expected] of [
  [{}, [80, 24]],
  [{ config: [40, 24] }, [40, 24]],
  [{ config: [32, 24] }, [32, 24]],
  [{ config: [20, 4] }, [20, 4]],
  [{ abi: { size: [40, 24] } }, [40, 24]],
  [{ abi: { size: [32, 24] } }, [32, 24]],
  [{ abi: { size: [20, 4] } }, [20, 4]],
  [{ config: [40, 24], abi: { size: [80, 24] } }, [80, 24]],
  [{ config: [32, 24], flags: 0, abi: { size: [40, 24] } }, [32, 24]],
  [{ config: [40, 24], abi: { pointer: 0 } }, [40, 24]],
  [{ config: [40, 24], abi: { size: [0, 24] } }, [40, 24]],
  [{ config: [40, 24], abi: { tag: "TNB", size: [32, 24] } }, [40, 24]],
  [{ config: [40, 24], legacyAbi: true }, [40, 24]],
  [{ legacyAbi: true, abi: { size: [32, 24] } }, [32, 24]],
  [{ config: [40, 24], abi: { major: 2, size: [21, 8] } }, [40, 24]],
  [{ config: [40, 24], abi: { major: 3, size: [21, 8] } }, [21, 8]],
  [{ config: [40, 24], abi: { major: 4, size: [21, 8] } }, [21, 8]],
  [{ config: [40, 24], abi: { major: 5, size: [21, 8] } }, [40, 24]],
  [{ config: [10, 2] }, [20, 4]],
  [{ config: [0, 0] }, [20, 4]],
  [{ config: [200, 150] }, [80, 24]],
  [{ abi: { size: [132, 43] } }, [80, 24]],
  [{ abi: { size: [21, 8] } }, [21, 8]],
]) {
  const { size, result } = selectScreen(options);
  assert.deepEqual(size, expected, JSON.stringify(options));
  configurationMeasurements[`select${expected.join("x")}`] = result;
}

function runEntry(machine, tail = "INPUT.NU") {
  setCommandTail(machine.memory, tail);
  let highBefore;
  const result = invokeRoutine(machine, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
    instructionLimit: 200_000_000,
    beforeRun() {
      highBefore = machine.memory.slice(machine.layout.top, 0x10000);
    },
  });
  assert.deepEqual(
    machine.memory.slice(machine.layout.top, 0x10000),
    highBefore,
    "EditorEntry wrote at or above the BDOS address",
  );
  assertCanaries(machine, { high: false });
  return result;
}

const memoryMeasurements = {};
for (const [label, top] of [
  ["high", HIGH_TPA_TOP],
  ["low", LOW_TPA_TOP],
]) {
  const layout = layoutFor(top);
  {
    const content = new Uint8Array(layout.capacity).fill(0x41);
    const machine = createMachine({
      top,
      files: { "INPUT.NU": physicalFile(content) },
    });
    writeWord(machine.memory, symbol("EditorTextCapacity"), 0);
    machine.bdos.input.push(0x42, 0x11);
    const result = runEntry(machine);
    assert.equal(result.exit, "warm-boot");
    assert.ok(result.stackBytes > 0 && result.stackBytes <= 32);
    assert.equal(
      readWord(machine.memory, symbol("EditorTextCapacity")),
      layout.capacity,
    );
    assert.deepEqual(bufferBytes(machine), content);
    assert.equal(
      machine.memory[symbol("EditorStatus")],
      symbol("EditorStatusFull"),
    );
    assert.equal(machine.bdos.terminal.snapshot().bellCount, 1);
    memoryMeasurements[`${label}Full`] = result;
  }
  {
    const machine = createMachine({
      top,
      files: {
        "INPUT.NU": physicalFile(new Uint8Array(layout.capacity + 1).fill(0x41)),
      },
    });
    const result = runEntry(machine);
    assert.equal(result.exit, "warm-boot");
    assert.equal(readWord(machine.memory, symbol("EditorLength")), layout.capacity);
    assert.ok(
      Buffer.from(machine.bdos.terminal.snapshot().cells)
        .toString("ascii")
        .includes("EDIT error 04"),
    );
    memoryMeasurements[`${label}Overflow`] = result;
  }
  {
    const machine = createMachine({
      top,
      files: { "INPUT.NU": physicalFile(Buffer.from("A\r\n", "ascii")) },
    });
    machine.bdos.input.push(0x42, 19, 0x11);
    const result = runEntry(machine);
    assert.equal(result.exit, "warm-boot");
    assert.deepEqual(
      logicalFileBytes(machine.bdos.files.get("INPUT.NU")),
      Uint8Array.from(Buffer.from("BA\r\n", "ascii")),
    );
    assertUnusedTextCanary(machine);
    memoryMeasurements[`${label}Save`] = result;
  }
}
{
  const minimumTop =
    memoryLayout.textStart + memoryLayout.stackSize + memoryLayout.textMinimum;
  const machine = createMachine({
    top: minimumTop,
    files: { "INPUT.NU": physicalFile(Buffer.from("A\r\n", "ascii")) },
  });
  machine.bdos.input.push(0x11);
  const result = runEntry(machine);
  assert.equal(result.exit, "warm-boot");
  assert.equal(
    readWord(machine.memory, symbol("EditorTextCapacity")),
    memoryLayout.textMinimum,
  );
  memoryMeasurements.minimum = result;

  const small = createMachine({ top: minimumTop - 1 });
  setCommandTail(small.memory, "");
  const before = small.memory.slice();
  const refused = invokeRoutine(small, "EditorEntry", {
    callerSp: ENTRY_CALLER_SP,
  });
  assert.equal(refused.exit, "return");
  assert.ok(refused.stackBytes > 0 && refused.stackBytes <= 16);
  for (let address = 0; address < 0x10000; address += 1) {
    if (address >= ENTRY_CALLER_SP - 32 && address < ENTRY_CALLER_SP) continue;
    assert.equal(
      small.memory[address],
      before[address],
      `refused entry wrote ${address.toString(16)}`,
    );
  }
  const screen = Buffer.from(small.bdos.terminal.snapshot().cells).toString(
    "ascii",
  );
  assert.equal(screen.slice(80, 160).trimEnd(), "EDIT error 06 TPA too small");
  assert.equal(small.bdos.events.length, 0);
  memoryMeasurements.refused = refused;
}

// Complete editing sessions at each supported screen size. The strict
// terminal rejects scrolling, wrapping, and addresses outside the screen.
const sessionLines = Array.from(
  { length: 30 },
  (_, index) =>
    `L${String(index).padStart(2, "0")}:${"abcdefghijklmnopqrstuvwxyz0123456789"
      .repeat(3)
      .slice(0, 96)}`,
);
const sessionFile = Buffer.from(`${sessionLines.join("\r\n")}\r\n`, "ascii");
const sessionLineBytes = sessionLines[0].length + 2;
const STATUS_HINTS = "  ^S Save  ^Q Quit";
const DOWN = [27, 0x5b, 0x42];
const RIGHT = [27, 0x5b, 0x43];
const LEFT = [27, 0x5b, 0x44];
const sessionQuery = Buffer.from("0123456789".repeat(7).slice(0, 64), "ascii");
const sessionReplacement = Buffer.from(
  "ABCDEFGHIJ".repeat(7).slice(0, 64),
  "ascii",
);

// An independent model of the status row. A pending message takes the
// position's place and is always whole: the base name is cut first, keeping
// the extension, then the filename is dropped, then the EDIT prefix.
function expectedStatus(
  columns,
  {
    name = "INPUT",
    extension = "NU",
    dirty = false,
    message = "",
    line = 1,
    column = 1,
  } = {},
) {
  const marker = dirty ? "*" : " ";
  const suffix = extension === "" ? "" : `.${extension}`;
  let left = `EDIT ${name}${suffix} ${marker}`;
  let text;
  if (message === "") {
    text = `${left}  L${line} C${column}`;
  } else {
    const shown = `  ${message}`;
    const room = columns - shown.length;
    const base = room - 7 - suffix.length;
    if (room < left.length) {
      if (base >= 1) left = `EDIT ${name.slice(0, base)}${suffix} ${marker}`;
      else if (room >= 6) left = `EDIT ${marker}`;
      else left = marker;
    }
    text = `${left}${shown}`;
  }
  if (columns - Math.min(text.length, columns) >= STATUS_HINTS.length) {
    text += STATUS_HINTS;
  }
  return text.slice(0, columns).padEnd(columns);
}

function expectedPrompt(columns, prompt, literal) {
  const visible = columns - 1 - prompt.length;
  const tail = Buffer.from(literal.slice(Math.max(0, literal.length - visible)))
    .toString("ascii")
    .replaceAll("\t", ">");
  return {
    row: `${prompt}${tail}`.padEnd(columns),
    cursorColumn: prompt.length + tail.length,
  };
}

// An independent model of the text rows: logical lines from the top offset,
// tabs expanded, clipped to the horizontal viewport.
function expectedTextRows(bytes, topOffset, horizontal, columns, textRows) {
  const result = [];
  let offset = topOffset;
  for (let row = 0; row < textRows; row += 1) {
    let line = "";
    if (offset < bytes.length) {
      const newline = bytes.indexOf(0x0a, offset);
      const end = newline === -1 ? bytes.length : newline;
      let content = Buffer.from(bytes.slice(offset, end)).toString("ascii");
      if (content.endsWith("\r")) content = content.slice(0, -1);
      for (const character of content) {
        line +=
          character === "\t" ? " ".repeat(8 - (line.length % 8)) : character;
      }
      offset = newline === -1 ? bytes.length : newline + 1;
    }
    result.push(line.slice(horizontal, horizontal + columns).padEnd(columns));
  }
  return result;
}

function runScreenSession({ columns, rows, top, abi = false, strict = true }) {
  const textRows = rows - 1;
  const machine = createMachine({
    top,
    columns,
    rows,
    strictTerminal: strict,
    files: { "INPUT.NU": physicalFile(sessionFile) },
  });
  machine.memory[symbol("EditorColumns")] = 0;
  machine.memory[symbol("EditorTextRows")] = 0;
  if (abi) {
    machine.memory.set(Buffer.from("TNA", "ascii"), 0xc003);
    machine.memory[0xc006] = 4;
    writeWord(machine.memory, 0xc008, 0xc040);
    machine.memory[0xc040] = columns;
    machine.memory[0xc041] = rows;
  } else {
    machine.memory[symbol("EditorConfigColumns")] = columns;
    machine.memory[symbol("EditorConfigRows")] = rows;
  }
  const steps = [
    ["down", Array(textRows).fill(DOWN).flat()],
    ["right", Array(columns + 5).fill(RIGHT).flat()],
    ["left", Array(10).fill(LEFT).flat()],
    ["insert", [0x58]],
    ["save", [19]],
    ["query", [6, ...sessionQuery]],
    ["cancelQuery", [27]],
    ["find", [6, 0x4c, 13]],
    ["replacement", [18, ...sessionReplacement]],
    ["cancelReplacement", [27]],
    ["discard", [0x59, 0x11]],
  ];
  const snapshots = [];
  let pending = "initial";
  machine.bdos.onIdle = () => {
    snapshots.push({
      name: pending,
      screen: machine.bdos.terminal.snapshot(),
      bytes: bufferBytes(machine),
      top: readWord(machine.memory, symbol("EditorTop")),
      horizontal: readVisualColumn(machine.memory, "EditorHorizontal"),
    });
    const next = steps.shift();
    pending = next?.[0];
    machine.bdos.input.push(...(next?.[1] ?? [0x11]));
  };
  const result = runEntry(machine);
  assert.equal(result.exit, "warm-boot");
  assert.equal(steps.length, 0);
  assert.equal(machine.bdos.input.length, 0);
  assert.equal(machine.memory[symbol("EditorColumns")], columns);
  assert.equal(machine.memory[symbol("EditorTextRows")], textRows);
  assert.ok(result.stackBytes > 0 && result.stackBytes <= 32);
  return { machine, result, snapshots };
}

function checkScreenSession({ columns, rows }, snapshots) {
  const textRows = rows - 1;
  const byName = Object.fromEntries(snapshots.map((entry) => [entry.name, entry]));
  const lastColumn = columns - 1;
  // line is the top viewport line; the status reports the cursor's source
  // line and visual column, both one-based.
  const at = (line, column) => ({ line, column });
  const views = {
    initial: { line: 0, horizontal: 0, cursor: [0, 0], status: at(1, 1) },
    down: {
      line: 1,
      horizontal: 0,
      cursor: [textRows - 1, 0],
      status: at(textRows + 1, 1),
    },
    right: {
      line: 1,
      horizontal: 6,
      cursor: [textRows - 1, lastColumn],
      status: at(textRows + 1, columns + 6),
    },
    left: {
      line: 1,
      horizontal: 0,
      cursor: [textRows - 1, columns - 5],
      status: at(textRows + 1, columns - 4),
    },
    insert: {
      line: 1,
      horizontal: 0,
      cursor: [textRows - 1, columns - 4],
      status: { dirty: true, ...at(textRows + 1, columns - 3) },
    },
    save: {
      line: 1,
      horizontal: 0,
      cursor: [textRows - 1, columns - 4],
      status: { message: "Saved", ...at(textRows + 1, columns - 3) },
    },
    cancelQuery: {
      line: 1,
      horizontal: 0,
      cursor: [textRows - 1, columns - 4],
      status: at(textRows + 1, columns - 3),
    },
    find: {
      line: 2,
      horizontal: 0,
      cursor: [textRows - 1, 0],
      status: { message: "Found", ...at(textRows + 2, 1) },
    },
    cancelReplacement: {
      line: 2,
      horizontal: 0,
      cursor: [textRows - 1, 0],
      status: at(textRows + 2, 1),
    },
    discard: {
      line: 2,
      horizontal: 0,
      cursor: [textRows - 1, 1],
      status: {
        dirty: true,
        message: "Discard? ^Q again",
        ...at(textRows + 2, 2),
      },
    },
  };
  const prompts = {
    query: ["Find: ", sessionQuery, "save"],
    replacement: ["Replace: ", sessionReplacement, "find"],
  };
  assert.deepEqual(
    snapshots.map((entry) => entry.name),
    [
      "initial",
      "down",
      "right",
      "left",
      "insert",
      "save",
      "query",
      "cancelQuery",
      "find",
      "replacement",
      "cancelReplacement",
      "discard",
    ],
  );
  for (const entry of snapshots) {
    const { screen } = entry;
    const label = `${columns}x${rows} ${entry.name}`;
    assert.deepEqual(screen.faults ?? [], [], label);
    const row = (index) =>
      Buffer.from(
        screen.cells.slice(index * columns, (index + 1) * columns),
      ).toString("ascii");
    const textAttributes = screen.attributes.slice(0, textRows * columns);
    const statusAttributes = screen.attributes.slice(
      textRows * columns,
      rows * columns,
    );
    assert.ok(textAttributes.every((value) => value === 0), label);
    assert.ok(
      statusAttributes.every((value) => value === ATTR_REVERSE),
      label,
    );
    const view = views[entry.name];
    if (view !== undefined) {
      assert.equal(entry.top, view.line * sessionLineBytes, label);
      assert.equal(entry.horizontal, view.horizontal, label);
      assert.deepEqual(
        Array.from({ length: textRows }, (_, index) => row(index)),
        expectedTextRows(
          entry.bytes,
          entry.top,
          entry.horizontal,
          columns,
          textRows,
        ),
        label,
      );
      assert.equal(row(textRows), expectedStatus(columns, view.status), label);
      assert.deepEqual([screen.cursorRow, screen.cursorColumn], view.cursor, label);
    } else {
      const [prompt, literal, previous] = prompts[entry.name];
      const expected = expectedPrompt(columns, prompt, literal);
      assert.equal(row(textRows), expected.row, label);
      assert.ok(expected.cursorColumn <= lastColumn, label);
      assert.deepEqual(
        [screen.cursorRow, screen.cursorColumn],
        [textRows, expected.cursorColumn],
        label,
      );
      assert.deepEqual(
        screen.cells.slice(0, textRows * columns),
        byName[previous].screen.cells.slice(0, textRows * columns),
        label,
      );
    }
    assert.equal(screen.bellCount, 0, label);
  }
}

const screenMeasurements = {};
let referenceSnapshots;
for (const size of [
  { columns: 80, rows: 24 },
  { columns: 40, rows: 24 },
  { columns: 32, rows: 24 },
  { columns: 21, rows: 8 },
  { columns: 20, rows: 4 },
]) {
  // The high TPA reads its size from the configuration block and the low TPA
  // from the TEC-OS console geometry.
  for (const [label, top, abi] of [
    ["high", HIGH_TPA_TOP, false],
    ["low", LOW_TPA_TOP, true],
  ]) {
    {
      const { machine, result, snapshots } = runScreenSession({
        ...size,
        top,
        abi,
      });
      checkScreenSession(size, snapshots);
      assert.deepEqual(
        logicalFileBytes(machine.bdos.files.get("INPUT.NU")),
        Uint8Array.from(
          Buffer.from(
            `${sessionLines
              .map((line, index) =>
                index === size.rows - 1
                  ? `${line.slice(0, size.columns - 5)}X${line.slice(size.columns - 5)}`
                  : line,
              )
              .join("\r\n")}\r\n`,
            "ascii",
          ),
        ),
      );
      screenMeasurements[
        `${size.columns}x${size.rows}${label === "high" ? "High" : "Low"}`
      ] = result;
      if (size.columns === 80 && !abi) referenceSnapshots = snapshots;
    }
  }
}
// Every status message appears whole at every supported width, with short,
// long, and extension-free filenames, clean and dirty.
const statusMessages = [
  ["EditorStatusSaved", "Saved"],
  ["EditorStatusFull", "Full"],
  ["EditorStatusDiscard", "Discard? ^Q again"],
  ["EditorStatusFound", "Found"],
  ["EditorStatusWrapped", "Wrapped"],
  ["EditorStatusNotFound", "Not found"],
  ["EditorStatusNoSearch", "No search"],
  ["EditorStatusReplaced", "Replaced"],
  ["EditorStatusSaveConflict", "Save failed 10"],
  ["EditorStatusSaveCreate", "Save failed 11"],
  ["EditorStatusSaveWrite", "Save failed 12"],
  ["EditorStatusSaveClose", "Save failed 13"],
  ["EditorStatusSaveRename", "Save failed 14"],
  ["EditorStatusSaveRollback", "Save failed 15"],
];
const statusMeasurements = {};
for (const { columns, rows } of [
  { columns: 80, rows: 24 },
  { columns: 40, rows: 24 },
  { columns: 32, rows: 24 },
  { columns: 21, rows: 8 },
  { columns: 20, rows: 4 },
]) {
  for (const filename of ["INPUT.NU", "NOTESABC.TXT", "README", "A.B"]) {
    const [name, extension = ""] = filename.split(".");
    for (const dirty of [false, true]) {
      for (const [status, message] of statusMessages) {
        const machine = createMachine({ columns, rows, strictTerminal: true });
        writeFcb(machine.memory, symbol("EditorFcb"), filename);
        machine.memory[symbol("EditorFlags")] = dirty
          ? symbol("EditorFlagDirty")
          : 0;
        machine.memory[symbol("EditorStatus")] = symbol(status);
        const result = invokeRoutine(machine, "EditorRenderStatus");
        const label = `${columns}x${rows} ${filename} ${message}`;
        const row = machine.bdos.terminal.row(rows - 1);
        assert.ok(row.includes(`  ${message}`), `${label}: message cut`);
        assert.equal(
          row,
          expectedStatus(columns, { name, extension, dirty, message }),
          label,
        );
        assert.deepEqual(machine.bdos.terminal.snapshot().faults, [], label);
        if (filename === "NOTESABC.TXT" && dirty) {
          statusMeasurements[`${columns}x${rows} ${message}`] = result;
        }
      }
    }
  }
}
{
  // Without a message the position returns, and at 20 columns the row is cut.
  const machine = createMachine({ columns: 20, rows: 4, strictTerminal: true });
  writeFcb(machine.memory, symbol("EditorFcb"), "NOTESABC.TXT");
  machine.memory[symbol("EditorStatus")] = 0;
  invokeRoutine(machine, "EditorRenderStatus");
  assert.equal(
    machine.bdos.terminal.row(3),
    expectedStatus(20, { name: "NOTESABC", extension: "TXT" }),
  );
  assert.equal(machine.bdos.terminal.row(3), "EDIT NOTESABC.TXT   ");
}

{
  // The strict terminal agrees with the reference 80-by-24 terminal model.
  const reference = runScreenSession({
    columns: 80,
    rows: 24,
    top: HIGH_TPA_TOP,
    strict: false,
  });
  checkScreenSession({ columns: 80, rows: 24 }, reference.snapshots);
  for (const [index, entry] of referenceSnapshots.entries()) {
    const other = reference.snapshots[index].screen;
    assert.deepEqual(entry.screen.cells, other.cells);
    assert.deepEqual(entry.screen.attributes, other.attributes);
    assert.deepEqual(
      [entry.screen.cursorRow, entry.screen.cursorColumn],
      [other.cursorRow, other.cursorColumn],
    );
  }
}
{
  // A configured image ignores the console geometry when its probe is off.
  const image = configureImage(binary.bytes, {
    columns: 40,
    rows: 24,
    probe: false,
  });
  const machine = createMachine({
    image,
    columns: 40,
    rows: 24,
    files: { "INPUT.NU": physicalFile(Buffer.from("A\r\n", "ascii")) },
  });
  machine.memory.set(Buffer.from("TNA", "ascii"), 0xc003);
  machine.memory[0xc006] = 4;
  writeWord(machine.memory, 0xc008, 0xc040);
  machine.memory[0xc040] = 32;
  machine.memory[0xc041] = 24;
  let status;
  machine.bdos.onIdle = () => {
    status ??= machine.bdos.terminal.row(23);
    machine.bdos.input.push(0x11);
  };
  const result = runEntry(machine);
  assert.equal(result.exit, "warm-boot");
  assert.equal(status, expectedStatus(40));
  assert.deepEqual(machine.bdos.terminal.snapshot().faults, []);
  configurationMeasurements.configuredImage = result;
}

const report = {
  assembled: {
    artifact: binary.bytes.length,
    code: memoryLayout.codeEnd - (memoryLayout.codeStart + 3),
    immutable: memoryLayout.immutableEnd - memoryLayout.immutableStart,
    workspace: memoryLayout.workspaceUsedEnd - memoryLayout.workspaceStart,
    textCapacity: capacity,
    partitionHeadroom: memoryLayout.workspaceStart - memoryLayout.residentEnd,
  },
  commands: commandMeasurements,
  loads: loadMeasurements,
  edits: editMeasurements,
  navigation: navigationMeasurements,
  search: searchMeasurements,
  replace: replaceMeasurements,
  saves: saveMeasurements,
  newFiles: newFileMeasurements,
  entry: entryMeasurements,
  configuration: configurationMeasurements,
  memory: memoryMeasurements,
  screens: screenMeasurements,
  statusRows: statusMeasurements,
};
console.log(
  `CP/M editor proof passed\n${JSON.stringify(report, undefined, 2)}`,
);
