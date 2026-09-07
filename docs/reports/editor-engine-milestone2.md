# Standalone editor engine: milestone 2

Status: complete; full owner check and independent review passed.

7 September 2026. The standalone editor now uses a lazily moved gap behind the document interface. Full rendering and existing command, file and process behaviour remain in place. This is a development candidate; no release or downstream pin has changed.

## Implementation

The document implementation stores two arena-relative gap boundaries. Loading creates an end gap. A validated splice moves the gap to the edit position, absorbs removed bytes and copies insertion bytes into the available space. Consecutive insertions at that point consume space without shifting the document tail. A full document has a zero-sized gap; equal-size replacement frees its removed bytes before inserting and needs no relocation copy.

Validation precedes relocation. Rejected edits and empty splices preserve the entire arena and both bounds. Logical byte access maps around the gap; forward/backward spans stop at its boundaries. Literal matching, range copies and removed-newline scanning consume those spans. The existing save adapter already accepts spans, including packing a record that crosses a physical boundary, so it required no production change.

Only the two document source files changed for the production gap implementation. Navigation, search policy, replacement policy, save transactions and full rendering use their milestone-one interfaces. A structural guard prevents production consumers from accessing the private gap words. The [current interface](../design/editor-engine-interface.md) documents the invariant, overlap-safe movement, pointer lifetime, loader precondition and unchanged operation/result contracts.

## Frozen comparisons

The original 3,107-byte editor remains in [its executable fixture](../../test/fixtures/editor-engine-baseline.json). Before changing storage, the verified milestone-one artifact was freshly assembled and checked against its completed report, then frozen as [a second executable fixture](../../test/fixtures/editor-engine-milestone1.json). It contains 3,872 bytes, restored ATOM symbols, source hashes, assembler identity and the uncommitted source-state inventory. Earlier raw measurement files remain unchanged.

Both measurement suites now execute all three artifacts. The original 17 workloads preserve the existing comparison cases. The new gap suite adds 16 workloads, including cold first edits and 100 subsequent complete typing commands at the beginning, middle and end of 16-KiB, 40-KiB and near-capacity source files. Every warm command's logical state, screen and disk digest is compared against both older artifacts. First edits after a distant search are counted separately from the search and warm typing.

## Verification

The retained tests cover the public interface and the new physical representation independently:

| Requirement | Evidence |
| --- | --- |
| Existing command/text/file behaviour | Original editor proof, adapted only for fixture setup and logical observation of gap storage |
| Document API contracts | 358 public routine calls including 240 seeded token-model splices, register/stack checks and failure atomicity |
| Semantic command contracts | 15 named semantic calls plus invalid opcode, 33 per-command full-snapshot comparisons and 128 final-record remainders |
| Gap positions and span traversal | 1,035 read/span/range/matcher calls across every position in a mixed CRLF/tab fixture, including a physical gap inside CRLF |
| Splice correctness and rejection | 1,693 splice cases, including all small endpoint combinations, empty/full/zero gaps, full-buffer replacement, forbidden aliases and patterned overlapping relocation with tiny gaps in both directions |
| Saving and recovery with a gap | 172 saves, covering all 128 gap-to-record alignments, write/close/install failures, successful rollback/retry, rollback failure and recovery, and new-file first save |
| Entry/exit and read-only invariants | Existing stack/exit proofs plus gap-context clean/discard exits; navigation, search, rendering and save preserve gap bounds and arena contents |
| Local typing movement | All warm typing samples assert zero text-arena block-copy reads; no primitive-only timing is substituted for a complete command |
| Capacity and memory | Assembled fixed partition and guards retain exactly 47,104 text bytes and the existing stack reservation |

The old unused-suffix canary assertion was representation-specific: gap bytes may contain stale text after a valid relocation or deletion. For gap artifacts, the observation helper instead validates ordered bounds and the exact length invariant. Tests still check outer workspace/high-memory guards, exact logical bytes, and complete physical arena/boundary preservation on rejected operations. This change does not permit gap bytes to enter rendered or saved text.

Independent implementation review found no required correctness defects. The full owner check includes ATOM policy, document ownership, build, original proofs, document/session/gap suites and both complete-command comparisons. `npm run check` passed the complete sequence, including all 17 retained and 16 gap workload comparisons.

## Measured account and limits

The candidate is 4,050 bytes: 3 entry bytes, 3,845 code bytes and 202 immutable bytes. Relative to milestone one, gap storage adds 178 code bytes and four workspace bytes. Total workspace is 342 of 512 bytes, leaving 170. The code partition has 3,374 unused bytes. Text capacity remains 47,104 bytes; the reserved private stack remains 3,072 bytes. No host runtime or extra text allocation is introduced.

Warm local typing copies zero document-tail bytes in every measured gap case. Beginning-of-file editing benefits most because the contiguous implementations repeatedly moved the longest suffix. End-of-file editing and long-line rendering can become slower: their previous copy cost was already small or zero, and retained navigation/rendering still performs individual logical-byte reads. Far search also includes expensive full viewport discovery. The [gap measurement report](editor-engine-gap-measurements.md) records these regressions alongside the improvements and separates editor CPU work, copying, terminal output and disk operations.

These are deterministic host Z80 measurements with fake BDOS and terminal services. BDOS implementation cycles, physical-machine timing and native/browser wall latency are not measured. Full redraw remains in every ordinary command measurement. A zero-copy insertion does not establish a fast complete keystroke.

The artifact SHA-256 is `28a001d1a8644de563f4abe01133f7ad4ec004de8649f64f9c85b1fd13b1ea45`. Its manifest is marked `0.1.1-dev` with `releaseBaselineMatch: false`. The release baseline remains unchanged, and strict release verification rejects this candidate without replacing the existing binary.

## Next milestone

Milestone 3 should reduce terminal output and repeated layout scans while preserving these document contracts. Its performance comparisons must include end-of-file and long-line regressions identified here, horizontal-follow behaviour and cold versus warm discovery. Partial redraw, viewport caches, IDE integration and release publication remain outside milestone two. Milestone three requires a separate goal activation.
