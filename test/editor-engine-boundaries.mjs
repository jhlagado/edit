// Public document contracts, using M1-only contiguous setup and an independent
// token/byte model. This is not a complete-keystroke performance benchmark.
import assert from "node:assert/strict";
import {
  assembleCurrent, createEngineMachine, executeRoutine, readWord, writeWord,
  logicalDocument, seedDocument,
} from "./support/editor-engine-harness.mjs";

const artifact = await assembleCurrent();
const symbols = artifact.symbols;
const capacity = symbols.EditorTextLimit - symbols.EditorTextBase;
const bytes = text => Uint8Array.from(Buffer.from(text, "ascii"));
const pair = (value, high, low) => ({ [high]: value >>> 8, [low]: value & 255 });
const hl = value => pair(value, "h", "l");
const de = value => pair(value, "d", "e");
const bc = value => pair(value, "b", "c");
let calls = 0;

function fresh(content = bytes("A\r\nB\tC\n")) {
  const m = createEngineMachine(artifact);
  // Recognisable session values reveal accidental command-state borrowing.
  m.memory.fill(0x39, symbols.EditorWorkspaceBase, symbols.EditorLegacyWorkspaceEnd);
  m.memory.fill(0x62, symbols.EditorSessionOpcode, symbols.EditorWorkspaceEnd);
  seedDocument(m, content);
  m.highGuard = m.memory.slice(symbols.EditorStackTop);
  m.memory[symbols.EditorDocChangeFlags] = 3;
  writeWord(m.memory, symbols.EditorDocChangeStart, 123);
  writeWord(m.memory, symbols.EditorDocChangeRemoved, 4);
  writeWord(m.memory, symbols.EditorDocChangeInserted, 5);
  return m;
}
function run(m, name, registers = {}) {
  const result = executeRoutine(m, name, { registers: { ix: 0x1357, iy: 0x2468, ...registers } });
  assert.equal(m.runtime.cpu.ix, 0x1357, `${name}: IX preservation`);
  assert.equal(m.runtime.cpu.iy, 0x2468, `${name}: IY preservation`);
  calls++;
  assert.equal(result.returnPc, 0x40, `${name}: return address`);
  assert.equal(result.finalSp, 0xe300, `${name}: final SP`);
  assert.deepEqual(result.bdosCalls, {}, `${name}: document must not call BDOS`);
  assert.equal(result.terminalBytes, 0);
  assert.equal(result.recordsRead, 0);
  assert.equal(result.recordsWritten, 0);
  assert.ok(result.minimumSp >= symbols.EditorStackFloor);
  return result;
}
function logical(m) {
  return logicalDocument(m);
}
function arena(m) { return m.memory.slice(symbols.EditorTextBase, symbols.EditorTextLimit); }
function session(m) {
  // Length belongs to the document. Every other legacy/session byte is private
  // to its caller and must survive even a successful document mutation.
  return [
    m.memory.slice(symbols.EditorWorkspaceBase, symbols.EditorLength),
    m.memory.slice(symbols.EditorLength + 2, symbols.EditorLegacyWorkspaceEnd),
    m.memory.slice(symbols.EditorSessionOpcode, symbols.EditorWorkspaceEnd),
  ];
}
function change(m) {
  return m.memory.slice(symbols.EditorDocChangeStart, symbols.EditorDocChangeFlags + 1);
}
function request(m, { start, remove = 0, input = new Uint8Array(), pointer = symbols.EditorDma, insert = input.length }) {
  if (input.length) m.memory.set(input, pointer);
  for (const [name, value] of Object.entries({ Start: start, Remove: remove, Input: pointer, Insert: insert }))
    writeWord(m.memory, symbols[`EditorDocument${name}`], value);
}
function splice(m, args) {
  request(m, args);
  const before = session(m);
  const result = run(m, "EditorDocumentSplice");
  assert.deepEqual(session(m), before, "splice changed caller-owned state");
  return result;
}
function reject(args, error, content = bytes("A\r\nB\tC\n")) {
  const m = fresh(content);
  request(m, args);
  const before = { arena: arena(m), length: readWord(m.memory, symbols.EditorLength), session: session(m) };
  const result = run(m, "EditorDocumentSplice");
  assert.equal(result.carry, true);
  assert.equal(result.a, symbols[`EditorDocumentError${error}`]);
  assert.deepEqual(arena(m), before.arena, "rejected splice changed unused arena bytes");
  assert.equal(readWord(m.memory, symbols.EditorLength), before.length);
  assert.deepEqual(session(m), before.session);
  assert.equal(m.memory[symbols.EditorDocChangeFlags], 0);
}

// Span endpoints, including empty/full files, distinguish an exclusive reverse
// endpoint from the forward byte offset convention. Read-only calls retain the
// previous mutation result and all caller state.
for (const content of [new Uint8Array(), bytes("A\r\nB"), new Uint8Array(capacity).fill(65)]) {
  const m = fresh(content);
  const oldChange = change(m), oldState = session(m), oldArena = arena(m);
  const offsets = [...new Set([0, 1, content.length - 1, content.length, content.length + 1, 65535])].filter(x => x >= 0 && x <= 65535);
  for (const offset of offsets) {
    let result = run(m, "EditorDocumentReadSpan", hl(offset));
    let count = (m.runtime.cpu.b << 8) | m.runtime.cpu.c;
    if (offset < content.length) {
      assert.equal(result.carry, false);
      assert.equal(result.hl, symbols.EditorTextBase + offset);
      assert.equal(count, content.length - offset);
      assert.deepEqual(m.memory.slice(result.hl, result.hl + count), content.slice(offset));
    } else { assert.equal(result.carry, true); assert.equal(count, 0); }
    result = run(m, "EditorDocumentReadSpanBackward", hl(offset));
    count = (m.runtime.cpu.b << 8) | m.runtime.cpu.c;
    if (offset > 0 && offset <= content.length) {
      assert.equal(result.carry, false);
      assert.equal(result.hl, symbols.EditorTextBase + offset - 1);
      assert.equal(count, offset);
      assert.deepEqual(m.memory.slice(result.hl - count + 1, result.hl + 1), content.slice(0, offset));
    } else { assert.equal(result.carry, true); assert.equal(count, 0); }
    result = run(m, "EditorDocumentReadByte", { ...hl(offset), ...bc(0xa731) });
    assert.equal((m.runtime.cpu.b << 8) | m.runtime.cpu.c, 0xa731);
    assert.equal(result.carry, offset >= content.length);
    if (offset < content.length) assert.equal(result.a, content[offset]);
  }
  assert.deepEqual(change(m), oldChange);
  assert.deepEqual(session(m), oldState);
  assert.deepEqual(arena(m), oldArena);
}

// Checked copies pin zero-count handling, exact EOF, no 64K transfer from BC=0,
// destination atomicity on bad source ranges, and alias/wrap rejection.
{
  const content = Uint8Array.from({ length: 300 }, (_, i) => 32 + i % 95);
  const target = symbols.EditorStackFloor + 0x100;
  const cases = [
    { offset: 0, count: 300 }, { offset: 127, count: 129 },
    { offset: 300, count: 0 }, { offset: 299, count: 1 },
    { offset: 301, count: 0, error: "Range" },
    { offset: 299, count: 2, error: "Range" },
    { offset: 65535, count: 2, error: "Range" },
    { offset: 0, count: 4, destination: 65534, error: "Range" },
    { offset: 0, count: 4, destination: symbols.EditorTextBase, error: "Alias" },
    { offset: 0, count: 4, destination: symbols.EditorTextLimit - 2, error: "Alias" },
    { offset: 0, count: 1, destination: symbols.EditorLength, error: "Alias" },
    { offset: 0, count: 1, destination: symbols.EditorLength + 1, error: "Alias" },
    { offset: 0, count: 4, destination: symbols.EditorLength - 1, error: "Alias" },
    { offset: 0, count: 4, destination: symbols.EditorDocChangeStart, error: "Alias", privateDestination: true },
    { offset: 0, count: 4, destination: symbols.EditorDocumentRangeOffset, error: "Alias", privateDestination: true },
  ];
  for (const { offset, count, destination = target, error, privateDestination } of cases) {
    const m = fresh(content);
    m.memory.fill(0x8b, target - 1, target + 301);
    const beforeTarget = m.memory.slice(target - 1, target + 301);
    const beforeArena = arena(m), beforeChange = change(m), beforeState = session(m);
    const beforeLength = readWord(m.memory, symbols.EditorLength);
    const result = run(m, "EditorDocumentReadRange", { ...hl(offset), ...de(destination), ...bc(count) });
    assert.equal(result.carry, Boolean(error));
    if (error) {
      assert.equal(result.a, symbols[`EditorDocumentError${error}`]);
      assert.deepEqual(m.memory.slice(target - 1, target + 301), beforeTarget);
      // Document scratch is explicitly volatile, including rejected requests.
      // Mutation-result fields are preserved even if named as bad destination.
      if (!privateDestination && destination === target)
        assert.deepEqual(m.memory.slice(destination, destination + count), beforeTarget.slice(1, 1 + count));
    } else {
      assert.equal(result.a, 0);
      assert.deepEqual(m.memory.slice(target, target + count), content.slice(offset, offset + count));
      assert.equal(m.memory[target - 1], 0x8b);
      assert.ok(m.memory.slice(target + count, target + 301).every(x => x === 0x8b));
    }
    assert.deepEqual(arena(m), beforeArena);
    assert.equal(readWord(m.memory, symbols.EditorLength), beforeLength);
    assert.deepEqual(change(m), beforeChange);
    assert.deepEqual(session(m), beforeState);
  }
}

// Invalid mutations: complete arena preservation is stronger than checking only
// logical content, and catches writes made before capacity/encoding validation.
reject({ start: 8 }, "Range");
reject({ start: 1, remove: 7 }, "Range");
reject({ start: 1, remove: 65535 }, "Range");
reject({ start: 2, input: bytes("X") }, "Text");
reject({ start: 1, remove: 1 }, "Text");
for (const input of [[13], [13, 65], [0], [26], [31], [127], [128], [255], [65, 13]])
  reject({ start: 0, input: Uint8Array.from(input) }, "Text");
reject({ start: 0, input: bytes("XY") }, "Capacity", new Uint8Array(capacity - 1).fill(65));
reject({ start: 0, insert: 65535 }, "Capacity");
reject({ start: 0, pointer: symbols.EditorTextBase, insert: 1 }, "Alias");
reject({ start: 0, pointer: symbols.EditorTextLimit - 1, insert: 2 }, "Alias");
reject({ start: 0, pointer: symbols.EditorTextBase - 1, insert: 2 }, "Alias");
reject({ start: 0, pointer: symbols.EditorLength, insert: 1 }, "Alias");
reject({ start: 0, pointer: symbols.EditorLength + 1, insert: 1 }, "Alias");
reject({ start: 0, pointer: symbols.EditorLength - 1, insert: 4 }, "Alias");
reject({ start: 0, pointer: symbols.EditorDocumentStart, insert: 1 }, "Alias");
reject({ start: 0, pointer: symbols.EditorDocChangeFlags, insert: 1 }, "Alias");
reject({ start: 0, pointer: symbols.EditorDocumentWorkspaceEnd - 1, insert: 2 }, "Alias");
reject({ start: 0, pointer: 65535, insert: 2 }, "Range");

for (const [original, start, remove, inserted, expected] of [
  ["ABCDE", 2, 0, "xy", "ABxyCDE"],
  ["ABCDE", 1, 3, "x", "AxE"],
  ["ABCDE", 1, 2, "xy", "AxyDE"],
  ["ABCDE", 1, 2, "BC", "ABCDE"],
  ["A\r\nB", 1, 2, "\n", "A\nB"],
  ["A\nB", 1, 1, "", "AB"],
  ["AB", 1, 0, "\r\n", "A\r\nB"],
  ["", 0, 0, "\t", "\t"],
  ["ABC", 3, 0, "", "ABC"],
]) {
  const m = fresh(bytes(original));
  const result = splice(m, { start, remove, input: bytes(inserted) });
  assert.equal(result.carry, false); assert.equal(result.a, 0);
  assert.deepEqual(logical(m), bytes(expected));
  const changed = remove !== 0 || inserted.length !== 0;
  const newline = original.slice(start, start + remove).includes("\n") || inserted.includes("\n");
  assert.equal(m.memory[symbols.EditorDocChangeFlags], changed ? 1 | (newline ? 2 : 0) : 0);
  if (changed) {
    assert.equal(readWord(m.memory, symbols.EditorDocChangeStart), start);
    assert.equal(readWord(m.memory, symbols.EditorDocChangeRemoved), remove);
    assert.equal(readWord(m.memory, symbols.EditorDocChangeInserted), inserted.length);
  }
}
{
  const m = fresh(new Uint8Array(capacity).fill(65));
  assert.equal(splice(m, { start: 20000, remove: 2, input: bytes("BC") }).carry, false);
  assert.equal(readWord(m.memory, symbols.EditorLength), capacity);
  assert.deepEqual(logical(m).slice(19999, 20003), bytes("ABCA"));
  assert.equal(splice(m, { start: 0, remove: 1 }).carry, false);
  assert.equal(splice(m, { start: capacity - 1, input: bytes("Z") }).carry, false);
  assert.equal(readWord(m.memory, symbols.EditorLength), capacity);
  assert.equal(logical(m).at(-1), 90);
}

// Seeded token model guarantees legal endpoints without copying the assembly's
// CRLF validation or mutation algorithm. Different tokens have unequal lengths.
{
  let seed = 0x6132b7;
  const random = limit => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed % limit; };
  const choices = ["a", "Z", " ", "\t", "\n", "\r\n", "!", "q"];
  let model = Array.from({ length: 600 }, (_, i) => choices[i % choices.length]);
  const m = fresh(bytes(model.join("")));
  for (let step = 0; step < 240; step++) {
    const first = random(model.length + 1);
    const last = first + random(model.length - first + 1);
    const additions = Array.from({ length: random(7) }, () => choices[random(choices.length)]);
    const start = model.slice(0, first).join("").length;
    const removed = model.slice(first, last).join("");
    const input = additions.join("");
    const result = splice(m, { start, remove: removed.length, input: bytes(input) });
    assert.equal(result.carry, false, `model step ${step}`);
    model = [...model.slice(0, first), ...additions, ...model.slice(last)];
    assert.deepEqual(logical(m), bytes(model.join("")), `model step ${step}`);
    const changed = removed.length + input.length !== 0;
    assert.equal(m.memory[symbols.EditorDocChangeFlags], changed ? 1 | ((removed + input).includes("\n") ? 2 : 0) : 0);
  }
}

// Literal matching must preserve its caller's query-length C and both search
// scratch words even on mismatch/EOF. Length-64 probes catch counter aliases.
for (const [text, query, offset, expected] of [
  ["ABCDE", "BCD", 1, true], ["ABCDE", "BXD", 1, false],
  ["ABCDE", "DE", 3, true], ["ABCDE", "DEF", 3, false],
  ["A\r\nB", "AB", 0, false], ["A\nB", "B", 2, true],
  ["", "X", 0, false], ["X", "X", 1, false], ["X", "X", 65535, false],
  ["A\tB", "\tB", 1, true], ["A\tB", " B", 1, false],
  ["A".repeat(64), "A".repeat(64), 0, true],
  ["A".repeat(64), "A".repeat(63) + "B", 0, false],
]) {
  const m = fresh(bytes(text));
  m.memory.set(bytes(query), symbols.EditorQueryBuffer);
  writeWord(m.memory, symbols.EditorScratchA, 0xbeef);
  writeWord(m.memory, symbols.EditorScratchB, 0x7139);
  const beforeState = session(m), beforeChange = change(m), beforeArena = arena(m);
  run(m, "EditorDocumentMatchLiteral", { ...hl(offset), ...de(symbols.EditorQueryBuffer), c: query.length, b: 0xa7 });
  assert.equal(m.runtime.cpu.flags.Z !== 0, expected);
  assert.equal(m.runtime.cpu.c, query.length);
  assert.deepEqual(session(m), beforeState);
  assert.deepEqual(change(m), beforeChange);
  assert.deepEqual(arena(m), beforeArena);
}

// Builder preserves live A/BC, leaves capacity rejection atomic and does not
// emit command mutations. Reset owns length/result flags, not session state.
{
  const m = fresh();
  const oldState = session(m);
  assert.equal(run(m, "EditorDocumentReset", bc(0x8923)).carry, false);
  assert.equal((m.runtime.cpu.b << 8) | m.runtime.cpu.c, 0x8923);
  assert.equal(readWord(m.memory, symbols.EditorLength), 0);
  assert.equal(m.memory[symbols.EditorDocChangeFlags], 0);
  for (const value of bytes("A\r\n\tB")) {
    const result = run(m, "EditorDocumentAppend", { a: value, ...bc(0x8923) });
    assert.equal(result.carry, false); assert.equal(result.a, value);
    assert.equal((m.runtime.cpu.b << 8) | m.runtime.cpu.c, 0x8923);
  }
  assert.deepEqual(logical(m), bytes("A\r\n\tB"));
  assert.deepEqual(session(m), oldState);
  const full = fresh(new Uint8Array(capacity).fill(65));
  const beforeArena = arena(full), beforeState = session(full), beforeChange = change(full);
  const result = run(full, "EditorDocumentAppend", { a: 90, ...bc(0x7a31) });
  assert.equal(result.carry, true); assert.equal(result.a, 90);
  assert.equal((full.runtime.cpu.b << 8) | full.runtime.cpu.c, 0x7a31);
  assert.deepEqual(arena(full), beforeArena);
  assert.deepEqual(session(full), beforeState);
  assert.deepEqual(change(full), beforeChange);
}
// Saturating change accounting distinguishes one reusable range from a batch;
// no finite generation counter can wrap back into an apparently valid cache.
if (symbols.EditorDocumentPendingChanges !== undefined) {
  const m = fresh(bytes("ABC"));
  const pending = () => m.memory[symbols.EditorDocumentPendingChanges];
  assert.equal(pending(), 2, "fixture replacement requires rediscovery");
  run(m, "EditorDocumentAcknowledgeChanges");
  assert.equal(pending(), 0);
  splice(m, {start: 1, input: bytes("x")});
  assert.equal(pending(), 1);
  splice(m, {start: 1, input: bytes("y")});
  assert.equal(pending(), 2);
  splice(m, {start: 1, input: bytes("z")});
  assert.equal(pending(), 2);
  splice(m, {start: 0});
  assert.equal(pending(), 2, "no-op cannot acknowledge a pending batch");
  run(m, "EditorDocumentAcknowledgeChanges");
  assert.equal(pending(), 0);
  run(m, "EditorDocumentReset");
  assert.equal(pending(), 2, "same-length reloads must still invalidate");
  run(m, "EditorDocumentAppend", {a: 65});
  assert.equal(pending(), 2);
}
console.log(`Editor document boundaries passed (${calls} public routine calls; 240 seeded model splices).`);
