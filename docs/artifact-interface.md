# Edit artifact interface

`npm run build` produces three ignored files in `dist/`:

- `EDIT.COM`: the CP/M transient loaded and entered at `$0100`;
- `EDIT.d8.json`: an optional symbolic debug map; and
- `manifest.json`: the machine-readable identity of the binary and assembler.

The manifest identifies exact release-baseline matches with
`releaseBaselineMatch: true`. A different development artifact has that field
set to `false` and a `-dev` version suffix. `npm run build:release` checks the
retained `release-baseline.json` before writing outputs; it rejects a different
artifact. The ordinary development build and tests can therefore run without
silently changing a release identity. The prepublish gate also runs the strict
release check. A development manifest is not a release qualification.

Consumers must select an immutable Edit revision, run its verified build, and
check the manifest before adding `EDIT.COM` to a disk image. They must not copy
or modify Edit's source in their own repository.

Cargo crates are the Rust equivalent of independently versioned library or
application packages, but `EDIT.COM` is not a Rust crate. Triptych should
record its selected Edit revision in a component lock and record the resulting
binary hash in its disk-image manifest. Cargo should continue to manage only
Triptych's Rust host and firmware code.

The 0.2.0 build uses native ATOM source modules and native dependency imports.
`sourceFormat: native-atom` identifies that input path. `symbolLedger` names
descriptive debug/test metadata; it is not a source-language converter. The
0.2.0 COM is byte-identical to the qualified milestone-three candidate, with
its new release identity accepted by the strict build.
