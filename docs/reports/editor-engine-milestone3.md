# Standalone editor engine: milestone 3

Status: complete; structural gates, full owner checks and host state audits pass. Proposed numerical targets retain documented misses.

This report records milestone three before the subsequent [native ATOM source migration](native-atom-migration.md). The current source/build path is documented there; the verified machine code is identical.

8 September 2026. The standalone editor now updates affected rows and caches visible layout positions. It retains the gap-backed document API, command behaviour and 47,104-byte text capacity. This is a development candidate; the release baseline and downstream component pins remain unchanged.

## Implemented behaviour

The main loop calls `EditorPresent` after a command. Layout returns cursor/status-only, one-row, affected-suffix or full damage. The presenter uses absolute row positions, paints at most 80 cells per affected row, clears short-row remainders, refreshes status only when needed and restores the document cursor. It avoids erase-line at exactly 80 output cells, where delayed wrapping could otherwise erase the final cell. A forced `EditorRender` invalidates layout and status and resets rendition before rebuilding the owned screen.

The layout stores 24 logical line boundaries and 23 compact anchors. Each three-byte anchor stores either a logical offset with a small tab phase relative to the horizontal origin, or the exact 24-bit visual column at a short line's end. The latter representation preserves backward horizontal movement without scanning the line again. Ordinary edits adjust later offsets; structural edits rebuild boundaries. All anchors are normalized before publishing a changed shared horizontal origin.

A saturating document change count distinguishes no pending edits, one usable change record, and a batch requiring reconstruction. Reset and load append force invalidation even when the new document has the same length. The layout acknowledges changes only after consuming them. This avoids a wrapping generation counter and does not make the document call the renderer. Prompts invalidate the status row separately from cached text.

A cached viewport supplies the cursor's row directly. When the cursor is outside it, discovery invalidates the cache before walking lines, avoiding repeated failed lookups through the old rows. Warm column calculation begins near the visible left edge. Cold discovery and certain backward tab-anchor movements remain scans; they are measured separately.

The current adapter owns the fixed 80-column, 23-row text area and the status row. A configurable rectangle for future embedding remains a proposed interface, not an implemented IDE view. The module split is synchronous subroutine calls; there is no host service, extra process, screen shadow or whole-file line index.

## Verification

The frozen milestone-two fixture preserves its 4,050-byte binary, symbols, assembler identity, source hashes and complete source text. It is an independent full-render reference, not a second path through the new layout. The milestone-three fixture records the final candidate binary and production source hashes.

| Requirement | Evidence |
| --- | --- |
| Existing standalone contracts | Original command, load, save/rollback, stack and exit proofs |
| Document API and change accounting | 366 public routine calls, including 240 model splices and saturating pending-change/reset checks |
| Semantic session | 15 named commands, invalid dispatch, 33 per-command comparisons and all 128 save-record remainders |
| Gap invariants | 1,035 read/span cases, 1,693 splices and 172 save cases |
| Incremental/reference equality | 1,143 exact command comparisons, including 1,000 deterministic mixed commands |
| Reset, batching and screen recovery | Seven batch/recovery comparisons, including same-length reload and external rendition/content contamination |
| Bounded warm scanning | 24 samples comparing short/long printable and tab-heavy lines and 23-row horizontal scrolling |
| Complete-command performance | 19 display workloads compared with the original, M1 and M2; earlier 17 and 16 workload suites retained |
| ATOM preparation | 600 colliding long symbol names and a byte-identical M2 rebuild after oversized-comment compaction |
| Host integration | Private disk readback, real native and browser execution, exact output completion and captured-frame audit; see host report |

Independent review found and corrected a final-empty-line bug: Down at EOF after a trailing newline initially returned success instead of the existing boundary status and bell. The retained mixed-command test reproduces the case. Review also prompted an explicit normal-rendition reset on forced repaint. The final cache-discovery change received a separate correctness review and passed the full display differential.

The ATOM preparation layer now accommodates more colliding projected symbol names. Flattened source larger than 60,000 bytes has ordinary comments and indentation removed before assembly, preserving quoted semicolons and machine annotations. This avoids ATOM's source-offset limit without switching assemblers or changing source semantics. The oversized frozen-M2 rebuild proves byte identity through this preparation path.

## Account, improvements and limits

The final candidate is 5,513 bytes: three entry bytes, 5,297 code bytes and 213 immutable bytes. It uses 490 of 512 workspace bytes, leaving 22, and leaves 1,911 bytes in the code partition. The text arena remains 47,104 bytes and the private stack reservation 3,072 bytes. Relative to M2, the artifact grows by 1,463 bytes and workspace by 148 bytes. The architecture and interface documents account for every cache field and scratch lifetime.

The [display measurement report](editor-engine-display-measurements.md) retains cold, warm, read, search, save, backward-tab and horizontal-scroll results. Warm source typing uses substantially less editor CPU work, and warm long-line scans no longer grow with hidden line length. Full horizontal repaint can emit more terminal bytes than M2 because each row is positioned explicitly. Cold reconstruction and search retain overhead. These costs are shown alongside the gains.

The proposed 100,000-T-state ordinary-edit target is not uniformly met, including some unchanged-viewport edits. The target is retained rather than revised. Full horizontal output remains particularly expensive. [Host qualification](editor-engine-host-qualification.md) distinguishes PTY completion, captured WindowServer presentation and browser DOM/frame opportunities; it does not infer physical hardware timing from guest counters.

The development build remains distinct from the release baseline. Strict release checking rejects a changed candidate; no release artifact, dependency pin or public deployment is part of this milestone. The source changes and documentation remain available for review in the existing editor branch.

## Final qualification record

`npm run check` passed on the final 5,513-byte candidate, including all behavioural proofs and 17/16/19 workload suites. The artifact hash is `6be83f6edb9ee92387c7b3817f473fbbc389a58ab1a20d9a2a6101e695fb77c4`. Independent review cleared the final viewport-discovery reset; the retained display suite passes 1,143 command comparisons.

Native PTY output p95 is 1.013 ms versus M2's 9.799 ms. Native captured WindowServer p95 is 67.277 ms versus 73.234 ms; both miss 50 ms under the recorded observer. Browser next-frame p95 is 32.600 ms versus 33.800 ms, a frame-opportunity proxy rather than verified physical presentation. Both native captures passed all 31 image audits and cleanup checks. Exact boundaries, raw samples and limitations are retained in the host report.

The milestone is complete as an implementation and measured qualification, with the numerical misses retained. It does not claim every keystroke meets the proposed CPU or presentation target. No fourth milestone, embedding work or publication is activated.
