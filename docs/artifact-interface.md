# Edit artifact interface

`npm run build` produces three ignored files in `dist/`:

- `EDIT.COM`: the CP/M transient loaded and entered at `$0100`;
- `EDIT.d8.json`: an optional symbolic debug map; and
- `manifest.json`: the machine-readable identity of the binary and assembler.

Consumers must select an immutable Edit revision, run its verified build, and
check the manifest before adding `EDIT.COM` to a disk image. They must not copy
or modify Edit's source in their own repository.

Cargo crates are the Rust equivalent of independently versioned library or
application packages, but `EDIT.COM` is not a Rust crate. Triptych should
record its selected Edit revision in a component lock and record the resulting
binary hash in its disk-image manifest. Cargo should continue to manage only
Triptych's Rust host and firmware code.
