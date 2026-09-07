# Historical dependency provenance

The retained measurement experiments originated at Edit revision
`ac59b478b686b7cd1a3a340064e82d64fdc58589`. `provenance.json` records the original
shared source paths and their SHA-256 hashes as historical evidence; those
fragment files are no longer present in this directory.

The experiments now have self-contained native ATOM entrypoints in the sibling
`buffer`, `search`, `new-file`, and `replace` directories. Their exact binary
identity and symbol values were verified during migration, as recorded in
`../native-migration.json`. They retain the original experiment byte assertions,
without importing current production editor changes. There is no executable
historical-source fallback or include tree.
