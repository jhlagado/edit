# Editor engine milestone 2: gap measurements

Date: 7 September 2026. Evidence is ATOM-built Z80 execution in the development runtime with a fake BDOS/terminal model. No native/browser input latency or physical hardware timing is inferred.

**The gap eliminates repeated tail copying, but the complete editor is not uniformly faster.** Both measurement suites pass: the original 17 workloads agree across all three artifacts, and 16 new gap workloads agree at every stage and every warm keystroke. Read-only navigation, search, rendering and saving preserve both gap bounds and make no CPU writes into the text arena. The original 17 baseline rows also match the preserved milestone 1-era baseline JSON data exactly; neither earlier raw report was overwritten.

## Artifacts and accounts

The comparisons deliberately keep the original editor and the completed contiguous milestone 1 editor separate. ATOM revision is `802b5c2d320bec777f427755ff2d7338e3b80a05`. Runtime/CPU source hashes, the runtime pin and Node version are in each raw report.

| Artifact | SHA-256 | COM bytes | Workspace bytes | Text capacity |
| --- | --- | ---: | ---: | ---: |
| original | `73265438a4f2df9a3f507f1bdcd49c48ebabe46cbcdb96e58dc0ee39f8b6a905` | 3,107 | 297 | 47,104 |
| milestone1 | `7b03e6ae7ae307def988460151bbea37c2a1d3caff7719edd4f09dd56b197fa1` | 3,872 | 338 | 47,104 |
| current | `28a001d1a8644de563f4abe01133f7ad4ec004de8649f64f9c85b1fd13b1ea45` | 4,050 | 342 | 47,104 |

The gap candidate adds 178 code bytes and four workspace bytes to milestone 1. Its entry remains three bytes, immutable data 202 bytes and reserved private stack 3,072 bytes; 3,374 bytes remain in the code partition. These figures identify the measured candidate, not a published release. Repeat the comparison after any production-source change.

| Account | Original | M1 | Gap | Gap minus M1 |
| --- | ---: | ---: | ---: | ---: |
| Entry | 3 | 3 | 3 | +0 |
| Code | 2,902 | 3,667 | 3,845 | +178 |
| Immutable data | 202 | 202 | 202 | +0 |
| Fixed workspace | 297 | 338 | 342 | +4 |
| Text arena | 47,104 | 47,104 | 47,104 | +0 |
| Reserved stack | 3,072 | 3,072 | 3,072 | +0 |

The observed maximum command depth from the private stack top is 24 bytes in all three artifacts; entry/load/initial-render depth is 20 bytes. These workloads do not bound every semantic or rollback path; retain the separate owner proofs for that purpose.

## Entry, load and initial render

These separately recorded setup costs run the real entry, command parser, full file load and initial rendering. They are not pure loader timings. Each implementation reads the same successful record count, writes exactly the logical length into the arena, performs zero arena block-copy reads during setup and emits 591 terminal bytes for these fixtures. The source is validated in the DMA record, so the arena scalar-read counter alone is not a loader-validation count.

| Logical bytes | Original T-states | M1 T-states | Gap T-states | Successful records read |
| --- | ---: | ---: | ---: | ---: |
| 16,384 | 6,150,621 | 6,319,105 | 6,692,827 | 128 |
| 40,960 | 14,854,101 | 15,268,345 | 16,133,587 | 320 |
| 46,848 | 16,939,350 | 17,412,474 | 18,395,476 | 366 |

## Complete typing commands

Each cold edit follows a real load, which must leave the gap at logical EOF. Fixture cursor positioning and its layout are explicitly excluded and recorded as setup. The cold command includes its relocation and complete redraw. It is followed immediately by 100 separately measured complete typing commands; their raw counters and per-key observable hashes are retained. The near-capacity fixture is 46,848 bytes, leaving 256 bytes for the cold edit and 100 warm insertions.

| Fixture | Cold gap T-states | Cold text bytes copied | Original warm 100 T-states | M1 warm 100 T-states | Gap warm 100 T-states | Gap vs M1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 16384-beginning | 749,189 | 16,384 | 74,959,099 | 75,845,099 | 48,715,899 | -35.77% |
| 16384-middle | 693,494 | 8,192 | 64,858,933 | 66,170,933 | 59,958,933 | -9.39% |
| 16384-end | 514,348 | 0 | 46,068,438 | 47,382,438 | 58,497,638 | +23.46% |
| 40960-beginning | 1,265,285 | 40,960 | 126,568,699 | 127,454,699 | 48,715,899 | -61.78% |
| 40960-middle | 922,268 | 20,480 | 88,184,912 | 89,462,912 | 57,061,912 | -36.22% |
| 40960-end | 485,578 | 0 | 45,074,936 | 46,324,936 | 56,800,136 | +22.61% |
| 46848-beginning | 1,388,933 | 46,848 | 138,933,499 | 139,819,499 | 48,715,899 | -65.16% |
| 46848-middle | 1,048,595 | 23,424 | 96,398,638 | 97,818,638 | 60,652,638 | -37.99% |
| 46848-end | 539,454 | 0 | 46,684,042 | 48,054,042 | 59,729,242 | +24.30% |

Every gap warm key copies **zero** bytes from the document through block moves. At the beginning of the near-capacity file, the original and M1 editors each copy 4,684,800 bytes during the 100-key burst; the gap copies none. At EOF, both contiguous editors already copy none, so additional access/validation costs outweigh the storage benefit. This is why the beginning and end results must remain separate.

These totals include all 100 redraws and the current horizontal-follow behaviour, including commands that cross the right edge. They are not a same-viewport-only sample. Even the fastest reported warm burst averages more than 100,000 editor-side T-states per command; the later incremental-display target has not been achieved by this storage milestone.

## Distant edits and whole-line costs

The distant-jump workload first inserts at the beginning, establishing a gap there. A real search then finds `TARGET` near EOF without moving that gap. The next edit is measured separately; it must pay for relocation. The long-line cases retain cold insertion and eight warm complete commands rather than extrapolating a primitive cost.

| Workload stage | Original T-states | M1 T-states | Gap T-states | Gap text bytes copied | Gap scalar text reads |
| --- | ---: | ---: | ---: | ---: | ---: |
| `distant-search-then-first-edit-16384/far-search-without-relocation` | 72,976,747 | 79,902,122 | 126,625,605 | 0 | 400,877 |
| `distant-search-then-first-edit-16384/first-edit-after-far-search` | 387,110 | 397,623 | 824,957 | 16,378 | 832 |
| `distant-search-then-first-edit-16384/warm-100-keys` | 44,736,719 | 45,989,719 | 56,324,119 | 0 | 103,400 |
| `read-layout-search-16384/move-right-left-without-relocation` | 689,975 | 700,321 | 792,821 | 0 | 925 |
| `read-layout-search-16384/find-across-gap-without-relocation` | 35,853,524 | 39,268,345 | 59,414,982 | 0 | 195,569 |
| `read-layout-search-16384/full-render-without-relocation` | 392,519 | 400,969 | 485,534 | 0 | 845 |
| `long-printable-cold-warm8/cold-first-edit` | 13,877,745 | 14,289,782 | 18,493,152 | 8,192 | 40,966 |
| `long-printable-cold-warm8/warm-8-keys` | 111,063,036 | 114,361,036 | 146,623,884 | 0 | 327,872 |
| `long-tabs-cold-warm8/cold-first-edit` | 26,437,556 | 26,644,803 | 28,747,038 | 4,097 | 20,487 |
| `long-tabs-cold-warm8/warm-8-keys` | 211,533,576 | 213,193,256 | 229,334,984 | 0 | 164,040 |

The first distant edit moves 16,378 bytes in the gap candidate, while the contiguous implementations only shift the six remaining suffix bytes. This is an expected locality tradeoff, not a hidden setup cost. Subsequent gap typing copies nothing again.

Search and long-line processing regress despite the absence of gap relocation. The unchanged navigation/layout consumers still make many logical byte accesses; the physical-gap translation adds work to those accesses. The measured far search performs 400,877 scalar text reads in the candidate. Long printable and tab-heavy rendering also retains the full-renderer cost. These regressions must not be described as improved complete keystroke latency. Converting the retained navigation/rendering loops to bulk-span traversal and adding incremental layout remain explicit follow-up work; this report does not claim they have already removed that cost.

## Whole-document traversal examples

The failed 16-KiB search tests every candidate start in one complete wrap, including query entry, bell and final rendering. Its editor-side costs are 6,339,615 original, 9,425,338 M1 and 12,289,386 gap T-states. Gap arena activity is 16,844 scalar reads and 0 block-copy reads. This is a complete-search measurement, not an isolated iterator benchmark.

The long printable-line workload traverses a whole 16-KiB logical line during rendering; cursor-column calculation adds overlapping prefix scans. Its warm-eight row above retains those repeated reads explicitly rather than presenting them as one unique traversal. Saving a whole document is measured separately with actual record-packing paths. Together these expose complete read/search/save costs without claiming that a raw span-fetch call represents the entire operation.

## Saving without compaction

A 16,391-byte file requires 129 physical records. The tests place the gap immediately before, on and after a 128-byte boundary. All saves reproduce the exact expected physical bytes, leave the gap unchanged and make zero CPU writes to the arena.

| Gap logical start | Gap save T-states | Source bytes copied to DMA | Physical records written |
| --- | ---: | ---: | ---: |
| 8,191 | 541,865 | 135 | 129 |
| 8,192 | 534,792 | 7 | 129 |
| 8,193 | 541,837 | 135 | 129 |

The unaligned cases pack one 128-byte record crossing the gap plus the seven-byte final partial record. The aligned case copies only the final seven bytes. Direct-DMA records are counted as storage operations, not editor CPU reads. Saving does not flatten the document or relocate its gap.

## Retained 17-case ruler

These are the same original workloads, now labelled against both frozen artifacts. Terminal byte counts and observable results agree across all three implementations. Full counters are in the raw comparison.

| Workload | Original T-states | M1 T-states | Gap T-states |
| --- | ---: | ---: | ---: |
| `typing-512-beginning` | 2,891,424 | 2,946,937 | 3,303,531 |
| `typing-512-middle` | 3,255,746 | 3,334,113 | 3,927,515 |
| `typing-512-end` | 3,552,710 | 3,649,157 | 4,451,973 |
| `typing-16384-beginning` | 5,557,920 | 5,613,433 | 3,636,843 |
| `typing-16384-middle` | 4,777,532 | 4,867,419 | 4,392,373 |
| `typing-16384-end` | 3,336,438 | 3,426,485 | 4,165,301 |
| `typing-47072-beginning` | 10,713,504 | 10,769,017 | 4,281,291 |
| `typing-47072-middle` | 7,524,460 | 7,622,027 | 4,964,885 |
| `typing-47072-end` | 3,401,290 | 3,493,257 | 4,251,273 |
| `far-jump-search-and-type-16384` | 76,091,220 | 83,098,752 | 125,011,900 |
| `alternating-far-jumps-16384` | 80,111,508 | 90,149,153 | 134,484,003 |
| `long-printable-16384` | 13,877,745 | 14,289,782 | 18,493,152 |
| `long-tabs-8193` | 27,975,162 | 28,305,169 | 31,583,121 |
| `search-no-match-16384` | 6,339,615 | 9,425,338 | 12,289,386 |
| `save-16384` | 408,741 | 460,009 | 528,025 |
| `save-47072` | 519,437 | 659,326 | 768,794 |
| `capacity-reject-47104` | 344,396 | 350,015 | 396,015 |

## Counter interpretation

Measurements run from `EditorMainLoop` before input to the next completed command boundary after rendering. Semantic full-render calls are labelled separately. Input/query handling, status/bell work and redraws are inside their declared intervals. Entry/load and fixture seeding/layout are outside those intervals with separate counters; only specialised read/save cases use a deliberately seeded middle gap.

CPU cycles cover executed editor instructions. The fake BDOS has no guest-cycle implementation, so the totals exclude real BDOS CPU time, storage latency and terminal transport. Raw `instructions` count runtime steps; repeated block instructions may be one step with complete repeated T-states. `textCopyReadBytes` counts arena source reads during block moves. `textScalarReadBytes` counts other arena reads, including repeated scans/validation, not unique bytes. Those categories must not be interpreted as a count of logical high-level scan operations. Terminal bytes and storage calls/records are independent counters.

Warm samples retain all 100 per-key measurements rather than only an average. They are deterministic command sequences, not 100 repeated host-latency trials. Final text/cells/attributes/files are compared by length/content digests, with cursor, status, flags and query state compared directly. The harness also exposes full snapshots for the independent correctness proofs.

Workspace/high-memory guards and command-boundary stack checks run during measurement. The separate gap-model, boundary and save-failure proofs remain necessary; performance workloads do not replace them. Native/browser wall-time qualification and physical hardware behaviour are not measured here.

## Reproduction

From the repository root:

```sh
node tools/measure-editor-engine.mjs --mode compare --output /tmp/editor-engine-gap-comparison.json
node tools/measure-editor-gap.mjs --output /tmp/editor-engine-gap-workloads.json
node tools/measure-editor-gap.mjs --only save-cross-gap
```

The original benchmark's `--mode baseline` still runs only the original frozen artifact. Neither command rewrites `dist`; only the explicitly selected report destination is written. Keep milestone 1 reports intact and use new output names for milestone 2.

Raw evidence: [17-workload comparison](editor-engine-gap-comparison.json), [gap-specific workloads](editor-engine-gap-workloads.json). Frozen artifacts: [original](../../test/fixtures/editor-engine-baseline.json), [milestone 1](../../test/fixtures/editor-engine-milestone1.json).
