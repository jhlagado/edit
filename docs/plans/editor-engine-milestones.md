# Editor engine: three implementation milestones

Date: 7 September 2026. Status: all three standalone engine milestones complete; numerical performance targets retain the measured misses documented below.

## Decision and scope

Evolve existing Edit into a reusable headless editor engine. Preserve its independently maintained Z80/CP/M program, file semantics and working tests while changing its internal structure. The [architecture specification](../design/editor-engine.md) defines the intended storage, command, layout and adapter boundaries.

This is an editor project, separate from the two-pane manager and Nucleus IDE. No manager, compiler, tool-return protocol, CCP changes, Triptych release integration or hosted deployment is required to complete these milestones. Future consumers can use a qualified editor later.

Starting from Edit retains tested search, CRLF handling, capacity rejection, save rollback and entry/exit behaviour. New internal routines may replace old ones where that produces the specified architecture; preserving the current implementation structure is not a requirement. A fresh editor would require reproducing those behaviours before its performance could be compared fairly.

Each milestone ends with a working standalone editor, technical documentation, complete accounting and passing owner checks. Production builds use ATOM only. Preserve unrelated changes, including the existing instruction-file deletion. Do not publish releases or update downstream pins as part of these goals.

## Milestone 1 — Measured baseline and reusable boundaries

**Evidence:** [completion report](../reports/editor-engine-milestone1.md), [implemented interface](../design/editor-engine-interface.md), and [complete-command measurements](../reports/editor-engine-measurements.md).

**Outcome:** a working editor whose document representation can change without rewriting search, saving or screen code, with repeatable measurements of current costs. Contiguous storage and full redraw remain in place.

Work:

1. Freeze the current source revision, dirty-state inventory, ATOM identity, rebuilt artifact and memory accounts. Preserve original benchmark outputs separately from post-refactor results.
2. Add a repeatable workload harness for complete editing commands, separating text copying/scanning, guest instructions/T-states, terminal bytes and storage work. Cover ordinary source, 16 KiB and near-capacity files; beginning/middle/end; sustained typing, far jumps, long printable/tab-heavy lines, search and save. Do not present primitive-only timings as keystroke latency.
3. Document the exact headless operation surface and ATOM register/flag/stack contracts: logical access, contiguous spans, validated range replacement, semantic commands and one synchronous change result. Record ownership and pointer lifetimes.
4. Move representation-dependent accesses behind the document interface, retaining contiguous storage. Audit loading, replacement and saving as well as the generic byte getter; remove unsupported direct arena assumptions from consumers. Keep command/session state separate from storage and terminal output.
5. Add meaningful behavioural pins around these boundaries. Compare logical state and final terminal/disk results with the frozen implementation and existing contract. Preserve failure outcomes and capacity rules.
6. Record complete before/after memory and execution accounts, with explanations for regressions. Update the architecture and migration notes to describe the actual retained shape.

Acceptance:

- Existing command, text/newline, cursor, search/replacement, new-file, save/rollback and entry/exit behaviour remains unchanged.
- Text capacity remains exactly 47,104 bytes; code/workspace/stack obey the declared partition, proved from assembled symbols and execution guards.
- Every production document access is accounted for: representation-private operations or documented logical/span access. An audit names and justifies any remaining privileged load-builder access.
- The benchmark distinguishes cheap and expensive cases and retains raw results. Command-level evidence includes all work at its declared boundary.
- Exact terminal state and saved bytes pass existing and added relevant tests; the complete `npm run check` passes.
- The repository contains an architecture/interface description, reproducible measurement instructions, a baseline report and a milestone completion report covering changes, evidence, limitations and the next step.

This milestone is complete only after both the refactor and its evidence exist. A baseline report alone is insufficient. It does not claim a gap-buffer speedup or partial redraw.

## Milestone 2 — Gap-backed document store

**Status:** complete. The completed milestone 1 artifact was frozen before changing storage. Comparisons retain both that intermediate baseline and the original editor. See the [completion report](../reports/editor-engine-milestone2.md) and [gap measurements](../reports/editor-engine-gap-measurements.md).

**Outcome:** the same standalone editor uses a lazily moved gap while retaining the full renderer as a stable comparison surface.

Implement the gap behind milestone 1's interface. Cursor movement, search, saving and layout do not relocate it. Span traversal avoids repeated logical-to-physical mapping for every byte. Load leaves an end gap; save streams through it and packs only records crossing the gap. Validate mutations completely before changing logical state, including equal-length replacement in a full buffer.

Acceptance:

- Independent logical-model tests cover gap positions, empty/full arena, zero gap, CRLF boundaries, alias rejection, search across the gap, replacement and every save-record alignment.
- Rejected operations preserve specified state; full save/rollback and entry/exit proofs pass.
- Subsequent insertions in a local typing burst copy no document tail. First edit after a distant jump includes relocation in its reported cost.
- Complete old/new traversal, search, save, code, workspace and stack accounts are reported; no hidden reduction in text capacity or off-account storage.
- The complete owner checks pass. A measured report explains gains and costs; architecture and interface documentation match production source.

Do not label complete keystrokes fast solely because gap insertion is fast: full rendering still exists at this milestone.

## Milestone 3 — Incremental display and bounded layout work

**Status:** complete. See the [completion report](../reports/editor-engine-milestone3.md), [display measurements](../reports/editor-engine-display-measurements.md) and [host qualification](../reports/editor-engine-host-qualification.md). Structural correctness and bounded-work gates pass; the proposed numerical CPU and native-presentation targets are not uniformly met and have not been relaxed.

**Outcome:** ordinary edits update affected rows, and warm typing avoids repeatedly scanning unchanged long prefixes and suffixes.

Add cursor-only, one-row, affected-suffix and full invalidation paths. Keep a development-only full-render reference for differential comparison. Add bounded visible-line and byte/column caches with explicit mutation invalidation. Preserve 24-bit visual columns and the current horizontal-follow policy. Measure right-edge typing separately because that policy can change every visible row.

Acceptance:

- Cells, attributes, cursor and bell match reference rendering after every tested command sequence, including failures, prompts, split/join, scrolling, tabs, EOF and cache resets.
- Cursor-only movement within an unchanged viewport emits no text-row repaint; same-line edits repaint at most their row when the viewport is unchanged.
- Warm long-line typing avoids rescanning unchanged line prefixes/suffixes. Cold discovery and distant jumps remain explicitly measured costs.
- The complete fixed workspace and text-capacity limits hold. Optional row buffers/checkpoints are measured allocations, not implicit reservations.
- The proposed architecture performance targets are measured against complete commands, with failures reported explicitly rather than averaged away. Native/browser wall-time qualification is recorded where a matching public harness is available; unavailable host evidence remains a named completion gap, not an inferred result.
- Owner checks and applicable standalone host integrations pass; technical reports retain workload data, exact artifacts, tradeoffs and any approved target revision.

## Documentation and verification discipline

Use repository documentation for durable technical material, with commands sufficient to reproduce measurements. Distinguish current measurements from historical reports, estimates, proposed targets and unavailable hardware evidence. Keep code/constants, writable workspace, text arena and stack as separate accounts. Record cold and warm paths separately.

Advance one milestone at a time. All three milestones are complete. No further implementation goal is activated by this document. Remaining numerical performance targets, future rectangle embedding and IDE features require separately scoped work.
