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

The complete guest-visible contract is in
[`docs/specification.md`](docs/specification.md). Historical design candidates
and their executable measurement tools are retained under `test/candidates`
and `tools`.

## Integration boundary

Consumers should take `EDIT.COM` and its manifest as immutable build outputs.
Triptych may place that artifact into a disk image; Debug80 may do the same for
development. Neither consumer owns Edit's source or build.

Edit calls CP/M entry address `$0005` and uses only the BDOS functions listed
in the specification. It expects the ANSI/VT-style terminal subset described
there. It does not embed a BIOS or depend on Triptych's Rust crates.

## License

GPL-3.0-or-later.
