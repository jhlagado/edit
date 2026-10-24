# Memory derived from the BDOS address and configurable screen size

Baseline: `24275017` (`v0.1.1`), ATOM revision
`802b5c2d320bec777f427755ff2d7338e3b80a05`, documented Z80, load/entry `$0100`.

Edit 0.1.1 fixed its upper memory at a 64 KiB layout: text `$2000..$D7FF`, a
private stack at `$D800..$E3FF`, and no writes at `$E400` or above. It also
fixed the screen at 80 × 24. On a system whose BDOS address is lower, such as
TEC-OS with `$B406` at `$0006`, the stack overlaps the BDOS. On a smaller
display the repaint scrolls and wraps. This revision removes both assumptions.

## Memory

Entry reads the BDOS address B from `$0006` before it writes any memory. If B
is below `$2500`, the 1,024-byte minimum arena plus the 256-byte stack would
not fit above `$2000`. The editor then prints `EDIT error 06 TPA too small` and
returns to the CCP on the caller's stack. Otherwise it stores the arena
capacity B − `$2100` in the workspace, loads SP from `$0006`, and runs. Load and
insertion compare against the stored capacity instead of a constant.

The private stack shrinks from 3,072 to 256 bytes. The deepest measured use is
24 bytes, and CP/M's BDOS switches to its own stack on entry. The arena gains
the difference.

| BDOS address | Text arena     | Capacity | Private stack  |
| ------------ | -------------- | -------: | -------------- |
| `$E400`      | `$2000..$E2FF` |   49,920 | `$E300..$E3FF` |
| `$B406`      | `$2000..$B305` |   37,638 | `$B306..$B405` |

The stack and arena now reach the CCP's memory, so the editor cannot return to
a resident CCP. Every exit after the stack switch is a jump to `$0000`, the
CP/M warm boot. The refused-entry path is the only return, and it writes
nothing. Visual columns still fit in 19 bits: an arena that ends at `$FFFF`
holds fewer than 57,344 tab bytes.

## Screen

The workspace holds the selected column count C and text-row count R − 1. Entry
selects them once:

1. With the probe flag set, the TEC-OS ABI tag `TNA` at `$FF00`, a nonzero
   geometry pointer at `$FF09`, and a nonzero column byte at that pointer, the
   console geometry is used.
2. Otherwise the configuration block at `$0103` supplies them: tag `ECFG`,
   version 1, columns, rows, and flags. The default is 80 × 24 with the probe
   enabled.

Both values are clamped to 20..99 columns and 4..99 rows. The upper limit is
the two-digit range of the existing cursor-address formatter. The new
`tools/configure.mjs` reads and sets the block and rejects out-of-range sizes.

Every former constant now reads the workspace:

- the repaint draws R − 1 text rows;
- the viewport scrolls once the cursor would pass row R − 1;
- the horizontal offset becomes V − (C − 1) once the visual column V reaches C;
- rendered text cells stop at column C;
- the status and prompt rows are addressed as row R; and
- status cells beyond column C are dropped.

The key hints appear only when all 18 bytes fit after the message. A prompt row
whose literal does not fit before the last column shows only the literal's
tail, so the cursor stays on the screen.

## Accounts

| Account                       | 0.1.1  | 0.2.0  | Delta |
| ----------------------------- | -----: | -----: | ----: |
| Complete COM bytes            | 3,107  | 3,289  |  +182 |
| Configuration block           |      0 |      8 |    +8 |
| Code excluding entry jump     | 2,902  | 3,058  |  +156 |
| Immutable bytes               |    202 |    220 |   +18 |
| Writable workspace used       |    297 |    301 |    +4 |
| Code-partition headroom       | 4,317  | 4,135  |  -182 |
| Private stack partition       | 3,072  |    256 | -2,816 |
| Text capacity at `$E400`      | 47,104 | 49,920 | +2,816 |
| Deepest measured stack use    |     24 |     24 |     0 |

The workspace gains the capacity word and the two screen bytes. The immutable
delta is the memory message and the ABI tag, less four bytes of the status
position string, which now carries only the column and rendition.

The artifact SHA-256 is
`2e5f6f9210a1ed29632a1ed2c0372e58dd47ddb3f4ab94ff854b9ce8759ee2d9`.

| Existing render proof at 80 × 24 | 0.1.1 T-states | 0.2.0 T-states |
| -------------------------------- | -------------: | -------------: |
| Tab render                       |         45,561 |         45,665 |
| Horizontal-scroll render         |        155,284 |        155,607 |
| Vertical-scroll render           |        150,204 |        151,144 |

## Proof

The existing proofs run unchanged at 80 × 24 with B = `$E400`, apart from the
new capacity, the routine harness's caller stack at B, and the warm-boot exit.
The new proofs cover:

- the configuration layout, defaults, and tool;
- size selection from the block and from the ABI, a disabled probe, a wrong
  tag, a zero pointer, zero columns, and clamping at both limits, with no
  write outside the two workspace bytes;
- a file that exactly fills the arena, the first rejected byte, and a rejected
  insertion at capacity, at B = `$E400` and B = `$B406`;
- a save at both addresses, the minimum arena, and the refused entry one byte
  below it; and
- one complete editing session at each of 80 × 24, 40 × 24, 32 × 24, and
  20 × 4, at both addresses.

The high-address sessions take their size from the configuration block and the
low-address sessions from the ABI. Each session checks every text row against
an independent line model, plus the status row, attributes, and cursor. It does
so after vertical scrolling, horizontal scrolling past the last column, a
return inside it, insertion, save, the 64-byte query and replacement prompt
rows, cancellation, search, and discard confirmation. It also checks the saved
file. A strict terminal model records any scroll, wrap, or out-of-screen
address as a fault, and every session must end with none. At 80 × 24 its
snapshots match the reference terminal model exactly.

| Session (B = `$B406`) | Instructions |     T-states | Stack |
| --------------------- | -----------: | -----------: | ----: |
| 80 × 24               |   24,174,090 |  250,115,980 |    24 |
| 40 × 24               |   15,110,307 |  154,554,596 |    24 |
| 32 × 24               |   13,440,715 |  137,141,018 |    24 |
| 20 × 4                |    1,289,261 |   13,102,308 |    24 |

These are host-model execution measurements, not physical-hardware timings. No
TEC-OS hardware or emulator run is included.

The historical candidate measurement scripts `measure:new-file` and
`measure:replace` already failed at the 0.1.1 baseline: they no longer
assemble against the current sources (undefined short symbols). This revision
leaves them as they were.
