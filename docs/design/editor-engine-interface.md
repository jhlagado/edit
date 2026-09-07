# Editor engine interface: document, session and display

Status: integrated milestone 3 interface, 7 September 2026; qualification is recorded in the milestone-three reports. The document and session operations established in milestones 1 and 2 remain in use. This revision records the layout cache and incremental presenter as implemented. The [architecture](editor-engine.md) defines scope and acceptance; the [guest contract](../specification.md) remains authoritative for user-visible behaviour.

The native ATOM migration preserves the binary and addresses. Descriptive routine
and field names in this document are restored in the debug map through
[`editor-symbols.json`](../../src/editor-symbols.json); committed ASM uses ATOM's
eight-character names, with descriptive comments at declarations. The ledger
does not rewrite assembled source or add code. All workspace equates now live
in [`editor-memory.asm`](../../src/editor-memory.asm).

## Execution model and ownership

The engine is a set of statically linked Z80 subroutines with one fixed document and one session. Calls are synchronous and non-reentrant. A caller completes an operation and consumes its result before issuing another operation. There is no allocation, event queue, second document, undo store or runtime service.

`editor-document.asm` owns the text arena and logical length. Its public offsets and counts are unsigned 16-bit byte quantities. The logical document is valid ASCII text containing tabs, LF and paired CRLF, with a maximum of 47,104 bytes. The physical arena contains a gap whose bytes are excluded from that logical sequence. Editing endpoints cannot divide CRLF. The session owns the cursor, committed query, desired column, flags and command status. The application adapter owns raw input, prompts, filenames, file transactions and process entry/exit. The layout module owns cached logical positions and display damage. The standalone presenter owns terminal output; its retained viewport helper applies the existing follow-cursor policy without emitting output.

Every public document routine preserves IX, IY and the caller's stack shape. CALL pushes the return address; RET consumes that same address, with no arguments left on the stack. AF, BC, DE and HL are volatile except where the table below promises preservation. Only documented flags have semantic meaning. Source `.routine` declarations describe register effects; executed tests establish the stated behaviour on the pinned Z80 runtime.

The engine requires valid code, workspace and stack placement supplied by its linker/application. The standalone shell supplies the existing fixed partition. A semantic test can initialise the document and session directly and call the same production routines without BDOS. Reusing the modules in another application still requires that application's initialisation and layout policy; the source interface does not provide a relocatable binary library or a second executable host.

## Document reads and validated loading

Names below have the `EditorDocument` prefix.

| Routine | Inputs | Result | Additional preserved registers |
| --- | --- | --- | --- |
| `Reset` | Valid fixed document workspace | Length zero, whole-arena gap, change flags zero, pending changes=2; A=0, carry clear | BC, DE |
| `Append` | A = one byte already validated by the loader | Byte appended, or carry set when full; A unchanged | BC |
| `ReadByte` | HL = logical byte offset | Carry clear, A=byte and HL=borrowed physical address; carry set at/beyond EOF | BC |
| `ReadSpan` | HL = logical first offset | Carry clear, HL=physical first byte, BC=nonzero forward count; carry set and BC=0 at/beyond EOF | None |
| `ReadSpanBackward` | HL = exclusive logical endpoint | Carry clear, HL=physical last byte, BC=nonzero backward count; zero/out-of-range returns carry set, BC=0 | None |
| `ReadRange` | HL = logical offset, DE = external destination, BC = byte count | A=0/carry clear on success; A=error/carry set on rejection | None |
| `MatchLiteral` | HL = logical offset, DE = external query, C = 1–64 bytes | Z=1 and A=0 for an exact match; Z=0 and A=1 for mismatch/EOF | BC |
| `Splice` | Four request words described below | A=0/carry clear on success; A=error/carry set on rejection | None |
| `AcknowledgeChanges` | Consumer has updated or discarded its derived state | Pending changes=0; A=0, carry clear; last range record unchanged | BC, DE, HL |

The backward endpoint may equal document length. Its address is the last byte of a span; iterating backwards decrements that address. A forward span ends at the gap or EOF. A consumer uses only the needed bytes and reacquires the next span from its logical offset. A backward span likewise stops at the gap or document start. Even a zero-sized gap may separate two adjacent spans, so consumers must not assume that one span covers the whole remaining document.

Read pointers are borrowed until the next reset, append or splice. Persistent session or display state stores logical offsets, never these addresses. Reading does not relocate storage or change the previous mutation result. `EditorBufferByteAt` remains a compatibility jump to `ReadByte`. Navigation and row painting still acquire individual bytes and incur their mapping/call cost, but layout caches bound ordinary visible-line work. The document matcher, range copier and save adapter consume spans in bulk.

`ReadRange` checks the complete source range and external destination before copying. A zero-length read at EOF succeeds without a transfer; an offset beyond EOF still fails. A nonempty external range cannot wrap the address space or overlap the text arena, the document length word, or document request/result/scratch. A range ending exactly at address 65,536 is conservatively rejected as wrapped. The caller also supplies writable destination storage that does not overlap active stack frames, code or live caller state. Those application-specific regions are not dynamically checked.

`MatchLiteral` requires a stable valid literal: printable ASCII or tabs, length 1–64, outside document scratch. It does not validate the query encoding or accept zero-length queries. EOF and a newline in the document prevent a valid literal from matching across that boundary. Matching preserves the outer search's candidate and remaining-count scratch words.

Loading uses `Reset` followed by `Append`. Reset creates a whole-arena gap; each append advances its left boundary while its right boundary stays at capacity. Append is restricted to this initial end-gap building phase, before interactive splices. This privileged builder permits an intermediate trailing CR while the loader awaits LF; it is not a public edit transaction. The loader validates the complete input, text EOF and capacity before entering the editor. A failed load can leave a partial document because no prior interactive document must be restored. Append preserves the loader's live A/BC and rejects a full arena before writing. A successful append sets pending changes to 2 but does not emit a splice range result. No other consumer writes length or arena bytes directly.

## Splice request and failure contract

The request consists of four little-endian words in fixed workspace:

| Field | Meaning |
| --- | --- |
| `EditorDocumentStart` | Logical beginning of the old range |
| `EditorDocumentRemove` | Number of old bytes removed |
| `EditorDocumentInput` | External insertion source address; ignored when insert count is zero |
| `EditorDocumentInsert` | Number of new bytes copied |

The operation replaces `[start, start + remove)` with the insertion bytes. It checks both endpoints, arithmetic overflow, final capacity, input lifetime/alias rules and the complete inserted encoding before moving text. Final capacity is computed after removal, so an equal-size replacement succeeds in a full document. A nonempty insertion cannot alias the text arena, length word or document-owned request/result/scratch. Other caller-owned input, including the small existing prompt buffer, must remain stable until return.

Error values are 1 for range/wrap, 2 for invalid text or a split CRLF endpoint, 3 for capacity, and 4 for a forbidden alias. When more than one condition is invalid, source-order validation determines the first error; callers should not rely on a different priority. Rejection leaves the complete arena, length and caller session state unchanged. Private scratch is volatile on all calls. The change flags become zero; old range words are then invalid.

After validation, the old removed range is scanned through logical spans for newline damage. The gap moves to the splice start, removed bytes are absorbed into its right edge, and insertion bytes consume its left edge. A gap already at the start requires no relocation. A zero-sized gap changes its boundary values without copying bytes, so full-buffer equal-size replacement remains valid. Other distant equal-size replacements may relocate an existing nonzero gap. There are no recoverable I/O failures during this mutation.

For arena-relative bounds `g0` and `g1`, the invariant is `0 <= g0 <= g1 <= capacity`, with `length = capacity - (g1 - g0)`. Logical offsets below `g0` address the prefix directly; offsets at or above it add the gap size. `EditorDocumentGapStart` and `EditorDocumentGapEnd` are private document words. Session, navigation, rendering and save code do not read or write them.

Moving left copies `[start,g0)` backwards to the old gap's right edge using LDDR. Moving right copies the necessary suffix prefix forwards into the left edge using LDIR. Both directions handle a gap smaller than the distance moved. The moved byte count is the logical distance to the requested start, except that zero-sized gaps require no copy. All zero-count transfers are skipped. Subsequent ordinary insertions at the new cursor consume the gap without copying document bytes.

Rejected edits and empty splices leave both gap bounds and the complete arena unchanged. Gap bytes can contain stale text after a move or deletion; they are not an untouched suffix and must never be rendered or saved. Physical gap positions inside CRLF are supported by reads and tested with synthetic fixtures, although accepted edit endpoints remain outside the pair.

## Synchronous results

A successful nonempty splice publishes three words: `EditorDocChangeStart`, `EditorDocChangeRemoved` and `EditorDocChangeInserted`. The one-byte `EditorDocChangeFlags` has bit 0 for an accepted edit and bit 1 when any LF/CRLF was removed or inserted. Range words are meaningful only while bit 0 is set. A zero-remove/zero-insert splice succeeds with no change flags. An identical replacement still counts as an edit, preserving the existing dirty-state contract.

Document reads preserve this record, even when a read is rejected. ReadRange and matching have dedicated scratch, separate from the record and from session scratch. Naming scratch itself as a rejected destination does not make scratch immutable; naming a mutation-result field still leaves that result intact. An independent review found the legacy length word initially missing from alias validation. The implementation and tests now explicitly protect both bytes and ranges crossing them.

`EditorSessionExecute` clears stale document change flags before dispatch, including commands that fail before any splice. It takes the operation in A and an insertion byte in E. It returns the selected command's original A and flags, with carry denoting failure. `EditorSessionOutcome` copies A. `EditorSessionResultFlags` contains these independently combinable bits:

| Bit value | Meaning |
| ---: | --- |
| 1 | Accepted document edit; consult document range record |
| 2 | Logical cursor differs from its pre-command value |
| 4 | Status or session flags differ from their pre-command values |
| 8 | Command returned carry set |

AF is saved while the summary is computed and restored before RET. BC/DE/HL are volatile; IX/IY and stack shape are preserved. Desired-column values can change while preparing vertical movement, even if movement fails. They are session state, not screen damage; the status/flags bit does not claim to report every scratch or desired-column write. The caller retains old viewport/cursor state when needed for later layout comparison.

### Pending changes and acknowledgement

`EditorDocumentPendingChanges` is a saturating byte, independent of the latest range record:

| Value | Meaning for a derived-state consumer |
| ---: | --- |
| 0 | No successful mutation since acknowledgement |
| 1 | One nonempty splice since acknowledgement; the latest range may support an incremental update |
| 2 | Reset, accepted load append, or multiple unacknowledged splices; rebuild derived state |

Every successful nonempty splice increments the value up to 2. Reads, failed splices and empty splices do not increment or clear it. Reset and every accepted append set 2, including a same-length reload. An identical accepted replacement still increments it. Saturation prevents an unobserved batch from wrapping back to a clean or single-change value.

A failed or empty splice, or a later semantic command, can clear the latest range flags while pending changes remains 1. Layout then rebuilds because the individual edit is no longer described. Two headless edits before presentation likewise force rebuilding, even though only the second range remains in the result record.

`EditorDocumentAcknowledgeChanges` clears only the pending byte. The layout calls it after updating or rebuilding its derived positions. Other consumers must not acknowledge on layout's behalf while leaving stale caches active; they can discard layout state with `EditorLayoutReset` first. This is a single-consumer, synchronous notification mechanism. It does not acknowledge terminal delivery, disk persistence or completion of an edit transaction.

## Semantic commands and shell adapters

Operation values 0–10 are Insert, Newline, Backspace, Delete, Left, Right, Up, Down, Find, FindNext and Replace. These values are internal source constants, not a published binary ABI. Unknown values return the existing boundary failure. Each command cancels pending discard confirmation. Editing, CRLF movement, search wrap and replacement cursor policy use the retained implementations.

Find and FindNext use `EditorQueryLength` and `EditorQueryBuffer`, populated with a valid committed literal by the shell or headless caller. Zero length yields the existing no-search outcome. Replace checks for the committed literal at the cursor and applies the accepted replacement without opening a prompt. Its length byte and up to 64 printable/tab bytes are staged at `EditorDma` and `EditorDma+1`. The historical name reflects the shell's storage reuse: this record is idle during semantic execution. The semantic path performs no DMA or BDOS operation. Concurrent file I/O or reentry would violate that lifetime contract.

The raw shell validates keys, edits prompts, restores cancelled queries, checks replace eligibility before prompting, and invokes the semantic command after acceptance. Save and Quit remain application operations because their file/terminal/process effects are not headless editing operations. The shell rings a bell on carry and calls `EditorPresent` after the command. A semantic call itself neither emits output nor adjusts the viewport. Presentation later applies the existing follow-cursor policy and updates the required rows. Complete-command measurements must include that presentation work.

## Layout and presentation interface

The current adapter owns a fixed 80-column by 24-row terminal: text rows 1–23 and status row 24. It has no rectangle parameter. A narrower embedded view remains future integration work and must supply its own clipping and bounded clearing rules.

Layout calls preserve IX/IY and the stack shape. Unless stated otherwise, AF/BC/DE/HL are volatile. Row indices are zero-based; logical offsets are 16-bit and visual columns are 24-bit.

| Routine | Inputs | Outputs and effects |
| --- | --- | --- |
| `EditorLayoutReset` | None | Clears layout validity and row count; A=0. BC/DE/HL survive. Document and pending changes remain intact. |
| `EditorLayoutPrepare` | Current document/session state | A=damage kind, B=first affected row; updates top/horizontal offsets and screen cursor, maintains caches and acknowledges document changes. No terminal or BDOS output. |
| `EditorLayoutGetRow` | A=row | HL=logical anchor, A:DE=anchor visual column; carry means blank. Writes `EditorLayoutRowEnd`, the logical content end excluding LF/CRLF. |
| `EditorLayoutCursorColumn` | Current logical cursor | A:HL=24-bit column, carry clear; uses the cursor or row cache where valid and the original scan otherwise. |
| `EditorLayoutFindLine` | HL=logical offset | Carry clear: HL=line start, A=row. Carry set: cache miss, original HL retained. BC survives. |
| `EditorLayoutNextLine` | HL=logical offset | A=0/Z means an answered result, with HL=next-line offset and carry indicating logical EOF; EOF is answered even without a valid cache. A=1/NZ means miss; the caller uses its raw scan. BC survives. |
| `EditorPresent` | Current session and owned terminal | Prepares layout, paints affected rows, updates changed status and places the cursor. |
| `EditorRender` | Current session and owned terminal | Discards layout/status validity, then forces a complete presentation. Use after load or known external screen replacement. |

Damage values are 0 for cursor/status only, 1 for one row, 2 for the affected row through row 22, and 3 for all text rows. B is zero for kind 3. A viewport change requires kind 3. A newline change can produce kind 2 only when the viewport remains unchanged; missing cache validity or an unobserved batch produces kind 3.

`Prepare` and the required row reads form one synchronous presentation. No document mutation or independent horizontal-origin change may intervene. `GetRow` returns a logical offset, not a borrowed physical pointer. The presenter reads through the document API and stops at `RowEnd` or 80 visible cells. Absent rows return carry set; other return values need not describe text for those rows. The presenter clears any unwritten row remainder.

The 24 cached boundaries contain up to 23 visible line starts and the following boundary. `EditorLayoutRowCount` distinguishes a real empty final line from absent rows; equal EOF offsets alone do not do so. Each of the 23 anchors occupies three bytes:

| Tag byte | Meaning of the preceding word |
| --- | --- |
| 0–7 | Logical offset of the byte covering the left edge; its start column is cached horizontal origin minus tag |
| `$80`–`$87` | Low 16 bits of the exact line-end visual column; tag's low three bits are its high bits |
| `$FF` | Anchor requires discovery |

For the end-column form, the logical content end comes from the following boundary, with any LF/CRLF removed. This form keeps short and empty rows blank without repeatedly scanning their text as the horizontal viewport moves. On a horizontal change, `Prepare` normalises all valid row anchors before publishing the shared new origin. Callers must not update that origin independently.

For one same-line edit, later boundaries and ordinary offset anchors shift by the byte delta. The active line start has left affinity. End-column words in later rows remain columns and do not shift. An active anchor made uncertain by an edit is invalidated. Newline changes, reset/load and unobserved batches rebuild boundary state. Cached cursor columns are refreshed from a nearby row anchor or, on a miss, the original scan.

Rightward anchor movement inspects the newly crossed bytes. Leftward movement over printable bytes decrements the known column directly. Crossing a tab backwards may require scanning its preceding printable run to recover the tab width modulo eight. Cold discovery, distant jumps and that backward-tab case can inspect a long prefix. Warm ordinary typing avoids repeated unchanged-prefix and hidden-suffix scans; it does not make every navigation command constant-time.

The presenter writes absolute positions for affected rows and clears their remaining cells with erase-to-end-of-line. A full presentation restores normal rendition, clears the owned screen and invalidates cached status. Status is redrawn when its dirty marker or status value changes, or when a prompt/full redraw has invalidated it. Prompt input invalidates status before using row 24. Presentation recalculates the real screen cursor afterwards, even if no text row changed. A cached viewport supplies the cursor row directly. When that lookup misses, discovery clears cache validity before walking lines, avoiding repeated probes of rows outside the old cache. The cursor-only path emits its own CSI prefix; `EditorPositionCursor` alone still requires that prefix from its caller.

All rows are repainted when horizontal following changes the viewport, which can happen on every keystroke at the right edge. Row anchors limit text inspection; they do not reduce that full-width output requirement. Terminal insert/delete-line operations, a screen shadow and an 80-byte staging row are not used.

## Migration audit

| Consumer | Retained implementation boundary |
| --- | --- |
| Load | Loader validates encoding; `Reset`/`Append` own storage writes |
| Insert, CRLF insertion, Backspace, Delete | Buffer wrappers construct a validated `Splice` request and apply session policy |
| Literal replacement | One `Splice`; prompt input remains stable in the idle DMA record |
| Search | Shared `MatchLiteral` scans document spans; outer candidate offsets and remaining count remain logical |
| Navigation | Cached line/column lookup with original scan fallback; logical byte access remains behind the document API |
| Layout and row painting | Bounded logical boundary/anchor caches; row painting reads only the clipped region through `ReadByte` |
| Save | Logical offset and remaining count; direct full record from a returned span or checked range copy into the DMA record |
| Length queries | Save/search read the document-owned logical length word; only document code writes it |

The removed `EditorBufferOpenGap` helper exposed contiguous-tail mutation and has no production compatibility shim. Remaining non-document block transfers initialise/copy FCBs, stage prompts, initialise layout state or pad DMA; they do not access the text arena. The source ownership guard rejects direct arena names or length stores outside their owner. It is a narrow structural check, supplemented by executed register, alias, state and no-I/O tests.

Save leaves the document representation unchanged. Full records wholly within a span use direct DMA; shorter or cross-span records are staged and only the final short record is padded with text EOF. The range copier handles physical gap crossings without flattening. The retained tests cover all 128 final-record remainders and all 128 positions of a gap within a record, alongside save failure and retry with a non-end gap.

## Accounting and qualification

The integrated workspace uses 490 of 512 bytes, leaving 22 bytes unallocated. Its accounts are 297 legacy bytes, 38 document bytes, 8 session bytes, 142 layout bytes and 5 display bytes. The document account includes four gap bytes and one pending-change byte; its legacy length word remains in the original account. Layout uses 48 bytes of boundaries, 69 bytes of tagged anchors, 13 bytes of persistent cursor/origin/validity state and 12 bytes of scratch. Text capacity and the 3,072-byte private-stack reservation are unchanged. Exact code/immutable extents and artifact identity belong in the freshly assembled measurement report rather than a copied earlier release total.

[Milestone 1 measurements](../reports/editor-engine-measurements.md) retain the original comparison. Frozen earlier binaries support the [gap comparisons](../reports/editor-engine-gap-measurements.md), and the [milestone-two completion report](../reports/editor-engine-milestone2.md) records that stage's verification and costs. Milestone 3 qualification must compare incremental output with the frozen full renderer, count inspected bytes on warm and cold paths, and report actual command costs separately from native/browser display latency. The [milestone-three completion report](../reports/editor-engine-milestone3.md) records qualification and the remaining numerical target misses.
