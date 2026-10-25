# Memory derived from the BDOS address and configurable screen size

Baseline: `20694826` (0.2.0 development, position status), ATOM revision
`802b5c2d320bec777f427755ff2d7338e3b80a05`, load/entry `$0100`.

The baseline fixed its upper memory at a 64 KiB layout: text `$2000..$D7FF`, a
private stack at `$D800..$E3FF`, and no writes at `$E400` or above. It also
fixed the screen at 80 × 24. On a system whose BDOS address is lower, such as
TEC-OS with `$B406` at `$0006`, the stack overlaps the BDOS. On a smaller
display the repaint scrolls and wraps. This revision removes both assumptions.
The same contract was first built and run on TEC-OS (40 × 24 and 21 × 8) and on
an 80 × 24 CP/M 2.2 system from a 0.1.1-based build.

## Memory

Entry reads the BDOS address B from `$0006` before it writes any memory. If B
is below `$2500`, the 1,024-byte minimum arena plus the 256-byte stack would
not fit above `$2000`. The editor then prints `EDIT error 06 TPA too small` and
returns to the CCP on the caller's stack. Otherwise it loads SP from `$0006`
and calls `EditorDocumentSetLimit` with B − 256. That routine records the
arena limit and capacity in the document workspace. Reset, append, splice
capacity checks, and the external-alias check read those words instead of
assembly constants. The text-arena names stay inside the document and memory
modules, as the ownership guard requires.

The private stack shrinks from 3,072 to 256 bytes. The deepest measured use is
24 bytes, and CP/M's BDOS switches to its own stack on entry. The arena gains
the difference.

| BDOS address | Text arena     | Capacity | Private stack  |
| ------------ | -------------- | -------: | -------------- |
| `$E400`      | `$2000..$E2FF` |   49,920 | `$E300..$E3FF` |
| `$B406`      | `$2000..$B305` |   37,638 | `$B306..$B405` |
| `$D900`      | `$2000..$D7FF` |   47,104 | `$D800..$D8FF` |

The stack and arena now reach the CCP's memory, so the editor cannot return to
a resident CCP. Every exit after the stack switch is a jump to `$0000`, the
CP/M warm boot. On TEC-OS the CCP is in ROM and the warm boot rebuilds its
state. The refused-entry path is the only return, and it writes nothing.

`editor-document.asm` is one of the pinned core modules, so
`editor-core.lock.json` and `tools/check-editor-core.mjs` are re-pinned to its
new SHA-256. The buffer and navigation modules are unchanged.

## Screen

The workspace holds the selected column count C and text-row count R − 1. Entry
selects them once:

1. With the probe flag set, the TEC-OS ABI tag `TNA` at `$FF00`, a nonzero
   geometry pointer at `$FF09`, and a nonzero column byte at that pointer, the
   console geometry is used.
2. Otherwise the configuration block at `$0103` supplies them: tag `ECFG`,
   version 1, columns, rows, and flags. The default is 80 × 24 with the probe
   enabled.

Columns are clamped to 20..80 and rows to 4..24. The row limit is the bounded
layout cache, which reserves boundaries and anchors for 23 text rows. The new
`tools/configure.mjs` reads and sets the block and rejects out-of-range sizes.

Every former constant now reads the workspace:

- the full repaint ends at row R − 1;
- the layout build stops after R − 1 rows;
- the viewport scrolls once the cursor would pass row R − 1;
- the horizontal offset becomes V − (C − 1) once the visual column V reaches C;
- painted cells and the erase-to-end-of-row decision use C;
- the status and prompt rows are addressed as row R; and
- status cells beyond column C are dropped.

The status row now shows the filename without FCB padding (`NOTES.TXT`, not
`NOTES   .TXT`). A pending status message takes the place of the
`L<line> C<column>` position until the next command clears it; before, it ran
into the position as `L1 C1Saved`. A message is always shown whole.

To make room, the row first cuts the base name and keeps the extension. If no
base byte fits, it drops the filename, and then the `EDIT ` prefix, leaving
only the dirty marker. The row measures the message by running the message
routine with output suppressed: a nonzero high byte of the render count
counts cells without writing them.

The messages lose their trailing padding, and the discard warning becomes
`Discard? ^Q again`, so the longest message needs 17 columns. A dirty
`NOTESABC.TXT` at 20 columns shows `EDIT NO.TXT *  Saved` and
`*  Discard? ^Q again`.

The key hints appear only when all 18 bytes fit. A prompt row whose literal
does not fit before the last column shows only the literal's tail, so the
cursor stays on the screen.

## Accounts

| Account                        | Baseline | Revised |  Delta |
| ------------------------------ | -------: | ------: | -----: |
| Complete COM bytes             |    5,890 |   6,222 |   +332 |
| Entry jump and configuration   |        3 |      11 |     +8 |
| Code                           |    5,674 |   5,994 |   +320 |
| Immutable bytes                |      213 |     217 |     +4 |
| Writable workspace used        |      494 |     501 |     +7 |
| Code-partition headroom        |    1,534 |   1,202 |   -332 |
| Private stack partition        |    3,072 |     256 | -2,816 |
| Text capacity at `$E400`       |   47,104 |  49,920 | +2,816 |
| Deepest measured stack use     |       24 |      24 |      0 |

The workspace gains the limit and capacity words, the two screen bytes, and
the measured message width. The memory message and the ABI tag add 22
immutable bytes. The status position string, which now carries only the column
and rendition, is four bytes shorter, and the shortened messages save 14 more.

## Proof

`test/prove-editor.mjs` runs the existing proofs with B = `$E400`, apart from
the new capacity, the routine harness's caller stack at B, the warm-boot exit,
and the compact filename. The new proofs cover:

- the configuration layout, defaults, and tool;
- size selection from the block and from the ABI, a disabled probe, a wrong
  tag, a zero pointer, zero columns, and clamping at both limits, with no write
  outside the two workspace bytes;
- a file that exactly fills the arena, the first rejected byte, and a rejected
  insertion at capacity, at B = `$E400` and B = `$B406`;
- a save at both addresses, the minimum arena, and the refused entry one byte
  below it; and
- one complete editing session at each of 80 × 24, 40 × 24, 32 × 24, 21 × 8,
  and 20 × 4, at both addresses; and
- every status message at each of those sizes, with short, long, and
  extension-free filenames, clean and dirty. Each row is checked exactly, and
  the message must appear whole.

The high-address sessions take their size from the configuration block and the
low-address sessions from the ABI. Each session checks every text row against
an independent line model, plus the status row (filename, position, and
message), attributes, and cursor. It does so after:

- vertical scrolling, horizontal scrolling past the last column, and a return
  inside it;
- insertion and save;
- the 64-byte query and replacement prompt rows, and their cancellation; and
- search and discard confirmation.

It also checks the saved file. A strict terminal model records any scroll,
wrap, or out-of-screen address as a fault, and every session must end with
none. At 80 × 24 its snapshots match the reference terminal model exactly.

| Session (B = `$B406`) | Instructions |   T-states | Stack |
| --------------------- | -----------: | ---------: | ----: |
| 80 × 24               |    4,249,735 | 44,031,934 |    24 |
| 40 × 24               |    2,573,030 | 26,558,434 |    24 |
| 32 × 24               |    2,255,194 | 23,238,790 |    24 |
| 21 × 8                |      836,161 |  8,520,615 |    24 |
| 20 × 4                |      583,246 |  5,900,539 |    24 |

The engine harness derives each artifact's layout. Frozen editors keep their
fixed `$E400` partition and CCP return. The current editor gets B = `$E400` by
default and its warm-boot exit is accepted. The engine, gap, and display
measurements run the current editor with B = `$D900`, which gives the frozen
editors' 47,104-byte arena, so capacity workloads compare like with like.
Differential comparisons normalise the status row to its words, which ignores
the position, the unpadded filename, and the message gap. The native-source
fixture moves to `editor-engine-screen-size.json`.

These are host-model execution measurements, not physical-hardware timings.
