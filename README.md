# Edit

Edit is a small, full-screen Z80 text editor for CP/M-compatible systems. It
is an independent guest program: it does not belong to Triptych, Debug80, or a
particular emulator.

The production source is assembled exclusively with
[ATOM](https://github.com/jhlagado/atom). The headless proof uses
[Debug80 Runtime](https://github.com/jhlagado/debug80-runtime) as a
development-only Z80 and terminal adapter; the editor binary has no Debug80
dependency.

## Build and verify

Node.js 22 or newer is required for the development tools.

```sh
npm ci
npm run check
```

The deterministic build writes `dist/EDIT.COM`, `dist/EDIT.d8.json`, and
`dist/manifest.json`. The proof executes the assembled Z80 code against a
minimal CP/M BDOS test boundary and checks editing, terminal, persistence,
rollback, memory, and stack behavior.

Development builds whose bytes differ from `release-baseline.json` carry a
`-dev` version and `releaseBaselineMatch: false` in their manifest.
`npm run build:release` requires exact agreement with that retained release
identity and fails before replacing outputs when it differs. The prepublish
gate includes this strict check. Development does not update release pins.

The complete guest-visible contract is in
[`docs/specification.md`](docs/specification.md). Historical design candidates
and their executable measurement tools are retained under `test/candidates`
and `tools`.

The current 0.2.0 editor is authored in native ATOM ASM modules. Its build uses
native imports directly; no source translator, name-shortening pass or ASMI
fragments remain. A descriptive symbol ledger preserves test/debug API names.
The [native migration report](docs/reports/native-atom-migration.md) records
byte identity, source cleanup, verification and release preparation.

The standalone engine refactor has a [three-milestone plan](docs/plans/editor-engine-milestones.md),
[architecture](docs/design/editor-engine.md), and [implemented interface](docs/design/editor-engine-interface.md).
Milestone 1 established contiguous-storage interfaces and full redraw. Its
[completion report](docs/reports/editor-engine-milestone1.md) and
[before/after measurements](docs/reports/editor-engine-measurements.md) record
the current evidence and costs. `npm run measure:engine` executes and compares
17 complete-command workloads against the frozen original and milestone-one editor. This comparison is
also part of `npm run check`.

Milestone 2 implements lazy gap storage while retaining full redraw. Its
[completion report](docs/reports/editor-engine-milestone2.md) and
[measurements](docs/reports/editor-engine-gap-measurements.md) record the
qualified behaviour, local-typing improvements and remaining regressions.
`npm run measure:gap` adds cold-edit and warm-typing measurements, checks every
warm command against both earlier editors, and asserts that reads, search and
saving do not relocate the gap. The full check includes this suite.

Milestone 3 adds incremental display and bounded layout caches. The
[display measurements](docs/reports/editor-engine-display-measurements.md)
compare complete commands with all three frozen earlier editors, including
cold discovery, horizontal scrolling and remaining target misses. The
[host qualification](docs/reports/editor-engine-host-qualification.md)
separates native output, captured presentation and browser frame opportunities.
`npm run measure:display` writes the current raw comparison. The full check
also includes 1,143 display comparisons and exact native-ATOM binary/symbol proofs.

`npm run measure` reproduces the earlier four design experiments. Their [native candidate sources](test/candidates/README.md) preserve the
historical experiment binaries separately from the current editor.

## Integration boundary

Consumers should take `EDIT.COM` and its manifest as immutable build outputs.
Triptych may place that artifact into a disk image; Debug80 may do the same for
development. Neither consumer owns Edit's source or build.

Edit calls CP/M entry address `$0005` and uses only the BDOS functions listed
in the specification. It uses the ANSI/VT-style terminal subset described
there. It does not embed a BIOS or depend on Triptych's Rust crates.

## License

GPL-3.0-or-later.
