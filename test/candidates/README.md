# Native ATOM measurement candidates

The fourteen `.asm` entrypoints in `buffer`, `search`, `new-file`, and
`replace` are self-contained native ATOM sources. Each entrypoint has a
matching `.asm.symbols.json` ledger from historical descriptive names to
native symbols. The ledger restores debugger/test names only; it does not
rewrite or prepare assembly source.

The one-time migration expanded the historical includes, selected each
candidate's conditional branches, supplied the existing zero-valued test
externs, and retained descriptive comments and routine contracts as comments.
Normal measurement runs assemble these checked-in sources directly with ATOM.
No conditional projection, include flattening, or symbol shortening runs during
assembly. No AZM assembler was executed for the migration.

`native-migration.json` records exact pre-migration binary hashes, native source
hashes and verified symbol counts. Every entry was assembled using the previous
ATOM path before conversion and directly with ATOM afterward; bytes and all
exported symbol values matched. The shared historical editor dependency revision
is recorded under `frozen-editor/`; its assembly fragments have been removed
because the native entrypoints now contain their selected code.
