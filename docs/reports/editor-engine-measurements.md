# Editor engine milestone 1: complete-command measurements

Historical milestone 1 result, frozen before the gap migration. Current source has progressed to milestone 2; the counts and hashes below identify the retained earlier artifacts.

Date: 7 September 2026. Evidence: ATOM-built Z80 execution in the development runtime and fake BDOS/terminal model. No hardware, native-terminal wall latency or browser wall latency is measured.

All **17 before/after workload comparisons pass**. Logical text, cursor/viewport, flags/status, committed query, terminal cells/attributes/cursor/bells and complete fake-disk files agree. The comparison asserts equality of state and content hashes; the harness also exposes the full byte/cell snapshots for other tests. Workspace and high-memory guards pass, as do command-boundary stack checks. Existing owner proofs remain the authority for the full behavioural and transaction-failure contract; this benchmark is additional evidence, not their replacement.

## Frozen input and memory accounts

The baseline fixture contains the actual rebuilt binary, ATOM symbols, per-source hashes and dirty-state inventory. Baseline HEAD is `74fc0328f35e814216031d21bf5aba715fb47232`. Source edits started only after freezing it. ATOM is pinned to revision `802b5c2d320bec777f427755ff2d7338e3b80a05`.

| Account | Frozen baseline | Current measured artifact | Delta |
| --- | ---: | ---: | ---: |
| COM bytes | 3,107 | 3,872 | +765 |
| Entry bytes | 3 | 3 | +0 |
| Code bytes | 2,902 | 3,667 | +765 |
| Immutable bytes | 202 | 202 | +0 |
| Fixed writable workspace | 297 | 338 | +41 |
| Text capacity | 47,104 | 47,104 | +0 |
| Reserved private stack | 3,072 | 3,072 | +0 |
| Unused code partition | 4,317 | 3,552 | -765 |

Baseline SHA-256: `73265438a4f2df9a3f507f1bdcd49c48ebabe46cbcdb96e58dc0ee39f8b6a905`.

Current SHA-256: `7b03e6ae7ae307def988460151bbea37c2a1d3caff7719edd4f09dd56b197fa1`. This identifies the measured uncommitted milestone candidate, not a published release. Subsequent production edits require regenerating the comparison.

Maximum observed depth from the private stack top is 24 bytes during measured command sequences and 20 bytes during entry/load/initial render. These are observed depths for these workloads, not a proof of the deepest path through every error/rollback operation. Semantic-routine calls use a separate synthetic caller stack; their depth fields must not be substituted for complete-command stack usage.

## Boundary and instrumentation

A complete-command measurement starts at `EditorMainLoop`, before reading the first queued byte, and ends at that same boundary after the last command's redraw. All query/replacement prompt input, dispatch, navigation, mutation, bell/status work and final rendering inside that interval are counted. Eight-character typing cases are totals for eight complete commands, not a primitive insertion timing. Far jumps are real search commands, not direct cursor assignment inside the measured interval.

Each file is opened through the actual entry, command parser and loader. That setup and initial rendering have separate raw counters. Beginning/middle/end fixtures set their initial cursor outside the command interval and perform a separately recorded layout/render. This makes the placement explicit; it does not call an uncounted repositioning operation in the middle of a measured command.

- `instructions` counts runtime steps. A repeated block instruction can be one step with its full repeated T-state cost; instruction counts alone conceal contiguous-tail copying.
- `tStates` counts the executed editor instructions. Fake BDOS service execution has no guest-cycle model, so these are **editor-side costs**, not total CP/M keystroke latency.
- `textReadBytes` counts actual CPU memory-read callbacks within the arena. `textCopyReadBytes` is its LDI/LDD/LDIR/LDDR subset, including text-to-DMA transfers. `textScalarReadBytes` counts the remaining reads: repeated traversal, matching and validation reads, not unique source bytes or a semantic number of scans.
- `textWriteBytes` counts CPU writes inside the arena. Fake BDOS file transfers use direct host buffers and are counted separately as successful 128-byte records plus call totals.
- `terminalBytes` counts each byte passed to direct console output, including escape sequences and bells. Final screen state is compared independently of byte volume.

The raw reports record the runtime pin, CPU/runtime source hashes and Node version. No elapsed time is converted to a guessed MHz or claimed physical latency.

## Complete-command results

Terminal byte counts are identical before and after for every row. No partial redraw or gap-buffer change is claimed at this milestone.

| Workload | Baseline T-states | Current T-states | Change | Terminal bytes |
| --- | ---: | ---: | ---: | ---: |
| `typing-512-beginning` | 2,891,424 | 2,946,937 | +1.92% | 4,764 |
| `typing-512-middle` | 3,255,746 | 3,334,113 | +2.41% | 4,780 |
| `typing-512-end` | 3,552,710 | 3,649,157 | +2.71% | 4,740 |
| `typing-16384-beginning` | 5,557,920 | 5,613,433 | +1.00% | 4,764 |
| `typing-16384-middle` | 4,777,532 | 4,867,419 | +1.88% | 4,774 |
| `typing-16384-end` | 3,336,438 | 3,426,485 | +2.70% | 4,580 |
| `typing-47072-beginning` | 10,713,504 | 10,769,017 | +0.52% | 4,764 |
| `typing-47072-middle` | 7,524,460 | 7,622,027 | +1.30% | 4,780 |
| `typing-47072-end` | 3,401,290 | 3,493,257 | +2.70% | 4,628 |
| `far-jump-search-and-type-16384` | 76,091,220 | 83,098,752 | +9.21% | 5,749 |
| `alternating-far-jumps-16384` | 80,111,508 | 90,149,153 | +12.53% | 3,636 |
| `long-printable-16384` | 13,877,745 | 14,289,782 | +2.97% | 235 |
| `long-tabs-8193` | 27,975,162 | 28,305,169 | +1.18% | 234 |
| `search-no-match-16384` | 6,339,615 | 9,425,338 | +48.67% | 1,413 |
| `save-16384` | 408,741 | 460,009 | +12.54% | 591 |
| `save-47072` | 519,437 | 659,326 | +26.93% | 591 |
| `capacity-reject-47104` | 344,396 | 350,015 | +1.63% | 592 |

The abstraction has measurable overhead. Typing regressions are small in these workloads; failed search and saving regress more substantially. Search repeatedly checks candidates through the new document boundary; save now obtains bounded document spans. The resulting call/range-check costs are included. Far-search cases also include expensive unchanged viewport discovery. These observations identify future measurement targets rather than justify bypassing the document interface.

Contiguous shifts remain visible: eight insertions at the beginning of the 47,072-byte fixture read **376,576 text bytes through block moves**, versus zero for eight end insertions. These copy counts are identical in the current candidate. A 16-KiB save writes 128 records; a 47,072-byte save writes 368, with 96 source bytes copied for the final partial record. Full-record direct DMA reads are storage work, not counted as editor CPU text reads.

The 8,193-tab case exceeds visual column 65,535 and retains the existing 24-bit handling. Its small terminal output does not imply cheap layout: the editor still scans and expands the long line internally. A future incremental renderer must measure this CPU work independently of output volume.

## Reproduction

From the repository root:

```sh
node tools/measure-editor-engine.mjs --mode baseline --output /tmp/editor-engine-baseline.json
node tools/measure-editor-engine.mjs --mode compare --output /tmp/editor-engine-comparison.json
node tools/measure-editor-engine.mjs --mode compare --only long-tabs
```

`baseline` uses the frozen fixture and never assembles current source. `compare` assembles current source with ATOM in a temporary directory, compares it against the same frozen artifact and writes only the explicit output destination. Neither path changes `dist`. Baseline/current modes can also run separately; only compare mode asserts cross-artifact equality. The harness can invoke named semantic routines separately, but those results must retain their semantic-only boundary label.

Evidence and tools:

- [Original executable and symbols](../../test/fixtures/editor-engine-baseline.json)
- [Original raw counts](editor-engine-baseline.json)
- [Before/after raw counts](editor-engine-comparison.json)
- [Execution harness](../../test/support/editor-engine-harness.mjs)
- [Workload runner](../../tools/measure-editor-engine.mjs)

The next milestone can measure a gap behind this same boundary. Local typing should stop copying the unchanged tail, while distant edits and whole-file traversal remain explicit costs. This report does not claim that improvement has happened.
