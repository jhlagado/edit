# Standalone editor engine: milestone 1 completion

Historical completion record. The [current interface](../design/editor-engine-interface.md) now includes milestone 2 gap storage; the measurements and acceptance evidence below describe the frozen milestone 1 candidate.

7 September 2026. Milestone 1 implements the document and semantic-command boundaries in existing Edit, retaining contiguous storage and full redraw. The complete owner check passes, and final independent review found no remaining required defects. This is a development candidate on `editor-engine-foundations`; no release or downstream pin has changed.

## Delivered behaviour

All production text mutation now passes through the document implementation. Insert/delete wrappers and literal replacement construct one validated splice request. Loading uses the documented append builder. Search matches logical spans, and saving streams logical records through span/range access. Navigation and rendering retain their byte-access compatibility entry point, which delegates to the document API.

The semantic dispatcher executes editing, movement, committed search and accepted replacement without terminal or file calls. It publishes content, cursor, status/flags and failure bits while preserving the selected command's A/flags result. Raw key handling, prompts, save transactions, process entry/exit and the existing full renderer remain in the standalone application.

The [implemented interface](../design/editor-engine-interface.md) specifies offsets, pointer lifetimes, registers, flags, stack, workspace, input aliases, failure atomicity, staged replacement lifetime and the complete consumer migration audit. The [architecture](../design/editor-engine.md) and [three-milestone plan](../plans/editor-engine-milestones.md) distinguish this implementation from the future gap and display work.

## Verification against acceptance

| Milestone requirement | Executed evidence |
| --- | --- |
| Preserve existing user and file semantics | Original `test/prove-editor.mjs` passes against freshly assembled production source, including save/rollback, newline, capacity, search/replacement and entry/exit cases |
| Validate document boundary independently | `test/editor-engine-boundaries.mjs`: 358 public calls, including 240 seeded token-model splices, forward/backward spans, range copies, invalid text/range/alias/capacity, full arena preservation on rejection and exact result records |
| Keep the core headless and define outcomes | `test/editor-session-boundaries.mjs`: 15 named semantic calls plus invalid opcode; result bits, failure status, discard cancellation and zero BDOS/terminal traffic checked |
| Preserve terminal and disk results after commands | 33 per-command full-snapshot comparisons against the frozen original; prompt acceptance/cancellation, mutation, navigation, failures, save and quit included |
| Preserve save record packing | All 128 final-record remainders compared through actual entry and save transactions; original suite retains empty/full-capacity and failure-path coverage |
| Preserve memory/stack contracts | Assembled partition assertions, public-call IX/IY/live-register checks, exact return PC/SP, workspace/high-memory guards and original complete-command stack proofs |
| Account for representation dependence | Source ownership guard plus reviewed migration table; arena access/length writes are document-owned, read-only length queries are explicit |
| Freeze and measure complete paths | Actual original binary, symbols, source hashes and dirty inventory retained; 17 deterministic workloads compare exact observable state and separately record copying, scalar reads, CPU T-states, terminal bytes, BDOS calls and records |
| Retain reproducible historical experiments | All four `npm run measure` suites pass using exact experiment dependencies frozen at their original extraction revision, with original size assertions unchanged |
| Complete owner gate | `npm run check` passes: ATOM policy, ownership guard, development build, original proof, both boundary suites and full engine comparison |

Independent review found that a checked range destination could overlap the document length word in its legacy workspace location. Validation now rejects overlap with either byte or a surrounding range. Regression cases cover both range reads and splice input. The review also identified historical experiment wrappers coupled to changing production source; their shared dependencies are now test-only frozen files with revision and hash provenance.

## Measured cost

The [complete-command report](editor-engine-measurements.md) contains the raw evidence, workload definitions and reproduction commands. The frozen editor is 3,107 bytes; this candidate is 3,872 bytes, an increase of 765 code bytes. Immutable data remains 202 bytes. Workspace grows from 297 to 338 bytes, leaving 174 bytes free. Text capacity is still exactly 47,104 bytes; reserved stack is still 3,072 bytes. The code partition has 3,552 unused bytes.

Ordinary eight-character typing workloads cost about 0.5–2.7% more editor T-states. Failed search in the measured 16-KiB case costs 48.7% more; 16-KiB and near-capacity saves cost 12.5% and 26.9% more. These regressions come with the new calls and validation/traversal boundaries and are retained explicitly in the report. This milestone establishes a replaceable representation and a measurement baseline; it does not claim faster editing.

Terminal output and contiguous-tail copying remain unchanged in the workload comparisons. Eight insertions at the beginning of a 47,072-byte document still copy 376,576 tail bytes. The next milestone can remove that repeated movement while using the same end-to-end comparison.

## Development artifact and retained limits

The candidate SHA-256 is `7b03e6ae7ae307def988460151bbea37c2a1d3caff7719edd4f09dd56b197fa1`. `npm run build` emits a development manifest with `releaseBaselineMatch: false` and version `0.1.1-dev`. The unchanged release baseline still identifies the original artifact. `npm run build:release` rejects this different candidate before replacing output files; that rejection and output preservation were checked directly. The prepublish gate includes the strict release check.

Evidence is from assembled Z80 execution using the development runtime and fake BDOS/terminal. CPU counts exclude the implementation of BDOS services, whose calls and transferred records are reported separately. No physical keystroke latency, browser timing or native-terminal wall time is claimed. Those integrations belong to later qualification.

The current engine is fixed-address, single-instance and non-reentrant. The session still uses the application's idle DMA record for accepted replacement staging. The document has no file-service dependency. No screen cache, gap, partial redraw, selection, undo or IDE integration has been added. Real cross-gap search/save alignment remains a milestone 2 obligation; every final-record remainder passing under contiguous storage does not prove a future gap implementation.

## Next milestone

Milestone 2 replaces contiguous storage with a lazily moved gap behind this interface. Keep full redraw as the stable display reference, add model and gap-position proofs, and measure first-edit relocation separately from subsequent local typing. Preserve the exact text capacity and report traversal/search/save costs as well as insertion gains. Milestone 2 requires its own goal activation; this completion does not start it.
