# Visual-column overflow correction

Baseline: `ac59b478` (`v0.1.0`), ATOM revision
`802b5c2d320bec777f427755ff2d7338e3b80a05`, documented Z80, load/entry `$0100`.
The baseline tree was clean. The fix is on `fix-visual-column-overflow`.

The focused regression initially failed: an 8,196-byte buffer containing 8,192
tabs, LF, and `ABC`, with cursor offset 8,192, moved down to offset 8,193 instead
of 8,196. The visual column 65,536 wrapped to zero. The unmodified full editor
proof passed, demonstrating its previous coverage gap.

Visual columns now use a low word and a separate high byte. The 47,104-byte
text capacity permits a maximum visual width of 376,832, requiring 19 bits.
Byte offsets and text capacity remain 16-bit. Desired column, horizontal
viewport, render column, and two navigation scratch values each gain a high
byte. There is no new external service or runtime dependency.

`EditorNavigationCursorColumn` returns `A:HL`; the offset mapper accepts a
target in `A:DE`. Tab advance returns a carry when its low word wraps. Both
ordinary characters and tabs carry into navigation high bytes. Offset mapping
and rendering compare high bytes before low words. Viewport subtraction
propagates its borrow. Load/reset clears the adjacent horizontal and desired
high bytes; rendering and navigation initialize their own scratch highs.

Render tab termination still compares low words: each tab expands to at most
eight cells, so the first equality identifies the same endpoint across a word
wrap. Each rendered cell independently advances the full visual column.

| Account | Baseline | Corrected | Delta |
| --- | ---: | ---: | ---: |
| Complete COM bytes | 3,003 | 3,107 | +104 |
| Code excluding initial jump | 2,798 | 2,902 | +104 |
| Immutable bytes | 202 | 202 | 0 |
| Writable workspace used | 292 | 297 | +5 |
| Text capacity | 47,104 | 47,104 | 0 |
| Code-partition headroom | 4,421 | 4,317 | -104 |
| Maximum measured stack depth below harness baseline | 24 | 24 | 0 |

The harness accounts for a direct routine's stack depth below its preinstalled
return address; that return address occupies another two bytes. Entry-path
measurements use the editor's private stack top. The fixed memory partitions
are unchanged: code `$0100..$1DFF`, workspace `$1E00..$1FFF`, text
`$2000..$D7FF`, stack `$D800..$E3FF`. Used workspace ends at `$1F29` exclusive.
The corrected resident image ends at `$0D23` exclusive. No generated-program
or shared-runtime bytes are added.

| Existing proof | Baseline T-states | Corrected T-states |
| --- | ---: | ---: |
| Down to short line | 8,184 | 8,390 |
| Down with retained desired column | 3,904 | 4,451 |
| Up with retained desired column | 2,960 | 3,059 |
| Tab render | 44,579 | 45,561 |
| Horizontal-scroll render | 149,022 | 155,284 |
| Vertical-scroll render | 146,278 | 150,204 |

Regression coverage now includes every reachable high-word boundary through
376,832 columns; exact byte-offset selection against an independent integer
walk; ordinary-character and tab carries; retained desired columns across
short CRLF lines; horizontal reset after wide lines; high-byte reset on load;
tab advance with incoming carry set; and exact framebuffer/cursor observations
for tab and ordinary-character render wraps. The full-capacity render case is
47,100 tabs followed by `TAIL`, taking 12,555,985 instructions and 131,065,370
T-states. Routine calls verify the actual return PC and restored SP; the proofs
also inspect text and workspace canaries and preserve source bytes.

`npm run check` runs the ATOM-only policy check, pinned-identity build, and
complete headless editor proof. The development build identity is updated to
3,107 bytes, SHA-256
`73265438a4f2df9a3f507f1bdcd49c48ebabe46cbcdb96e58dc0ee39f8b6a905`.
This change does not create a release, tag, or push.

These are host-model execution measurements, not physical-hardware timings.
Rendering still walks every expanded cell in a logical line; very long tabbed
lines remain slow. This correction restores their column semantics without
introducing a line-length restriction or changing accepted file bytes.
