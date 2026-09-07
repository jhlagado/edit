import assert from "node:assert/strict";
import { assembleCurrent, loadBaseline, createEngineMachine, beginSession, executeCommands,
  executeRoutine, engineSnapshot, memoryAccounts, physicalFile, readWord, writeWord } from "./support/editor-engine-harness.mjs";

const [current, baseline] = await Promise.all([assembleCurrent(), loadBaseline()]);
const accounts = memoryAccounts(current);
assert.equal(accounts.textCapacity, 47104);
assert.equal(accounts.reservedStackBytes, 3072);
assert.ok(accounts.workspaceBytes <= accounts.workspaceCapacity);
assert.ok(accounts.codeRoom >= 0);
const bytes = source => Uint8Array.from(Buffer.from(source, "ascii"));
const machine = createEngineMachine(current, {files: {"INPUT.NU": physicalFile(bytes("abc\r\nxyz\nabc"))}});
beginSession(machine);
const { memory, symbol, runtime } = machine;
const word = name => readWord(memory, symbol(name));
const byte = name => memory[symbol(name)];
let commands = 0;
function command(op, value = 0) {
  const beforeCells = engineSnapshot(machine).cells;
  const result = executeRoutine(machine, "EditorSessionExecute", {registers: {a: symbol(`EditorOp${op}`), e: value}});
  assert.equal(result.terminalBytes, 0, `${op}: terminal-independent`);
  assert.deepEqual(result.bdosCalls, {}, `${op}: no BDOS calls`);
  assert.deepEqual(engineSnapshot(machine).cells, beforeCells, `${op}: no implicit rendering`);
  assert.equal(result.a, byte("EditorSessionOutcome"));
  assert.equal(Boolean(byte("EditorSessionResultFlags") & 8), result.carry);
  assert.equal(Boolean(byte("EditorSessionResultFlags") & 1), Boolean(byte("EditorDocChangeFlags") & 1));
  commands++;
  return result;
}
function query(text) {
  memory[symbol("EditorQueryLength")] = text.length;
  memory.set(bytes(text), symbol("EditorQueryBuffer"));
}
function replacement(text) {
  memory[symbol("EditorDma")] = text.length;
  memory.set(bytes(text), symbol("EditorDma") + 1);
}
assert.equal(command("Insert", 65).carry, false);
assert.equal(byte("EditorSessionResultFlags"), 7, "insert: content, cursor, dirty");
assert.equal(word("EditorCursor"), 1);
assert.equal(word("EditorDocChangeStart"), 0);
assert.equal(word("EditorDocChangeRemoved"), 0);
assert.equal(word("EditorDocChangeInserted"), 1);
command("Left");
assert.equal(byte("EditorSessionResultFlags"), 2, "cursor-only semantic movement");
assert.equal(byte("EditorDocChangeFlags"), 0, "read command clears stale mutation result");
assert.equal(command("Backspace").carry, true);
assert.equal(byte("EditorSessionResultFlags"), 12, "boundary: failure and status");
assert.equal(command("Backspace").carry, true);
assert.equal(byte("EditorSessionResultFlags"), 8, "repeated failure has no new status");
command("Delete");
assert.equal(byte("EditorSessionResultFlags"), 5, "delete: content and status; cursor fixed");
query("abc");
assert.equal(command("Find").carry, false);
assert.equal(word("EditorCursor"), 0);
assert.equal(byte("EditorSessionResultFlags"), 4);
command("FindNext");
assert.equal(word("EditorCursor"), 9);
replacement("abc");
command("Replace");
assert.equal(byte("EditorSessionResultFlags") & 1, 1, "identical replacement is still an edit by existing contract");
assert.equal(word("EditorCursor"), 9);
assert.equal(word("EditorDocChangeRemoved"), 3);
assert.equal(word("EditorDocChangeInserted"), 3);
command("Newline");
assert.equal(byte("EditorDocChangeFlags"), 3);
assert.equal(word("EditorCursor"), 11);
command("Backspace");
assert.equal(word("EditorCursor"), 9);
assert.equal(word("EditorDocChangeRemoved"), 2, "CRLF is one deletion");
command("Up");
command("Down");
command("Right");
query("");
assert.equal(command("FindNext").carry, true);
assert.equal(byte("EditorStatus"), symbol("EditorStatusNoSearch"));
// A new semantic command cancels discard confirmation even on failure.
memory[symbol("EditorFlags")] |= symbol("EditorFlagConfirmQuit");
command("FindNext");
assert.equal(byte("EditorFlags") & symbol("EditorFlagConfirmQuit"), 0);
assert.equal(byte("EditorSessionResultFlags") & 4, 4);
const invalid = executeRoutine(machine, "EditorSessionExecute", {registers: {a: 255}});
assert.equal(invalid.carry, true);
assert.equal(byte("EditorDocChangeFlags"), 0);
assert.deepEqual(invalid.bdosCalls, {});

// Each command is compared, not merely the eventual final file. This exercises
// prompt acceptance/cancellation, state following failed commands, and repaint.
const sequences = [
  {text: "one\tword\r\ntwo words\nlast", keys: [
    [27,91,68], [8], [65], [27,91,67], [13], [8], [127], [27,91,66], [27,91,65],
    [6,...bytes("word"),13], [14], [18,...bytes("WORDS"),13], [19],
    [65], [17], [27,91,68], [6,27], [18,27], [14], [0x01], [19], [17]]},
  {text: "", keys: [[8], [127], [27,91,65], [27,91,66], [14], [18], [9], [13], [65], [19], [17]]},
];
let compared = 0;
for (const {text, keys} of sequences) {
  const pair = [baseline,current].map(artifact => {
    const m = createEngineMachine(artifact,{files:{"INPUT.NU":physicalFile(bytes(text))}});
    beginSession(m); return m;
  });
  assert.deepEqual(engineSnapshot(pair[1]), engineSnapshot(pair[0]));
  for (const key of keys) {
    pair.forEach(m => executeCommands(m,key));
    assert.deepEqual(engineSnapshot(pair[1]),engineSnapshot(pair[0]),`command ${compared}: ${key}`);
    compared++;
  }
}
// Save record packing: every possible final-record length, including zero and
// exact records. Use actual entry and save transaction, compare all disk bytes.
for (let remainder = 0; remainder < 128; remainder++) {
  const text = new Uint8Array(128 + remainder).fill(65 + remainder % 26);
  const pair = [baseline,current].map(artifact => {
    const m = createEngineMachine(artifact,{files:{"INPUT.NU":physicalFile(text)}});
    beginSession(m); executeCommands(m,[19]); return m;
  });
  assert.deepEqual(engineSnapshot(pair[1]),engineSnapshot(pair[0]),`save remainder ${remainder}`);
}
console.log(JSON.stringify({semanticCommands: commands, perCommandDifferentialChecks: compared,
  saveRecordRemainders: 128, accounts, result:"pass"},null,2));
