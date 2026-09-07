# Native ATOM editor migration and 0.2.0 preparation

8 September 2026. Native source migration is verified. Commit, push and Triptych consumer integration are being completed separately.

The editor now builds directly from native ATOM modules. The output remains exactly 5,513 bytes with SHA-256 `6be83f6edb9ee92387c7b3817f473fbbc389a58ab1a20d9a2a6101e695fb77c4`, matching the qualified [milestone-three fixture](../../test/fixtures/editor-engine-milestone3.json). All 534 descriptive symbol values remain unchanged. Editing, screen, file and process behaviour is unchanged by this migration.

## Source and build

Native dependency imports are placed at the beginning of the root source in the required order. A prologue module emits the origin and entry jump before executable modules; the root body retains the immutable data. Former nested memory fragments were combined once into the native memory module. This respects ATOM's dependency-before-importer semantics without treating imports as textual inclusion.

Committed labels meet ATOM's eight-character limit. Descriptive names remain in declaration comments and a checked one-to-one symbol ledger. The build applies that ledger only to emitted debug metadata, so existing semantic tests can identify the same addresses. ATOM assembles the committed names directly. Routine contracts remain comments backed by executed register, flag, state and stack tests; ATOM does not newly claim to statically enforce them.

The shared assembly helper no longer translates source, rewrites symbols, flattens includes, projects obsolete output directives, evaluates legacy conditionals or compacts comments. Unused 8080/OS conversion helpers were removed from this editor repository. There is no executable fallback. The pinned ATOM package still distributes its own unused migration utility; this is not an AZM dependency or an editor build step.

All ASMI files were removed. Production modules use ASM, and the fourteen historical candidates are self-contained native ASM with adjacent symbol ledgers. Their binary bytes and exported symbol values match the captured pre-migration candidates. [Candidate provenance](../../test/candidates/native-migration.json) records each comparison. Historical reports and the frozen JSON source snapshot remain evidence, not executable source fallbacks.

## Verification

`node test/atom-native.mjs` proves all 5,513 bytes and 534 symbol values against the frozen milestone-three artifact. The original editor, document, session, gap and display proofs pass, including 1,143 exact display command comparisons. The complete `npm run check` includes those tests and the 17, 16 and 19 complete-command workload suites. `npm run measure` also passes all four historical experiment suites through the native candidate builder.

Independent review checked native callers, output range, all debug-symbol identities and source locations, and representative forbidden ownership expressions. The ownership guard decodes native names through the ledger before applying its existing semantic checks; it has not become an empty name search. It remains a narrow structural guard, supported by execution proofs. The assembler policy also rejects active translation imports and obsolete ASMI files.

The code, immutable bytes, workspace, text capacity, stack reservation and Z80 execution costs are unchanged from milestone three because the binary is identical. Earlier native/browser measurements therefore identify the same machine code, rather than fresh timing observations from source migration. CPU and presentation target misses in the milestone-three reports remain valid.

## Release and integration

The strict release baseline and package identity are 0.2.0. `npm run build:release` produces the exact verified COM and an ATOM manifest with native-source provenance. The release uses the existing fixed workspace at 1E00, 47,104 text bytes at 2000 and stack ending below E400. A consumer must check the complete memory partition against its resident layout, not just the 5,513-byte file size.

Triptych replacement must select the committed and pushed Edit revision and matching COM/manifest/provenance, then qualify its native and WASM/browser workflows. The private image prepared during this task is a review artifact; it does not upgrade a user's saved disk. Consumer integration evidence will be recorded in Triptych after its own checks pass.
