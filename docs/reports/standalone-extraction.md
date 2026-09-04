# Standalone extraction report

Date: 2026-09-05

## Source and history

Edit was extracted from `jhlagado/debug80` at
`fa7ad9b2826c8cffded397c830a5ea900d883c1a`. The filtered history retains 37
commits and the complete production source, specification, proof, design
candidates, and measurement reports owned by Edit. The first production
vertical slice remains traceable to the rewritten history commit `0f4e75f3`.

The source Debug80 checkout was restored to its prior tracked state after the
history operation. Its only status entry was the pre-existing untracked
`.worktrees/` directory.

## Ownership boundary

- `src/` owns the portable Z80 editor.
- `docs/specification.md` owns the guest-visible editor, BDOS, memory, and
  terminal contract.
- `test/prove-editor.mjs` owns the isolated executable contract proof.
- `test/candidates/` and `tools/measure-*.mjs` retain the measured design
  alternatives without putting them on the release path.
- Triptych and Debug80 are consumers of `EDIT.COM`; neither owns these sources.

The production binary has no host dependency. Debug80 Runtime is a
development-only Z80/terminal adapter used by tests and measurements.

## ATOM-only result

The former executable sidecar oracle was removed. A clean dependency graph now
selects ATOM revision `802b5c2d320bec777f427755ff2d7338e3b80a05` for every
normal build, proof, and measurement path.

`npm run build`, `npm test`, and all four candidate measurement suites pass on
macOS. The standalone artifact is byte-identical to the pre-extraction
baseline:

| Property | Value |
| --- | --- |
| File | `EDIT.COM` |
| Size | 3,003 bytes |
| SHA-256 | `bbe4ac2b6236d178089fcd01822d0d7fa3c6159f0d2da3655eba1212dda5aa02` |
| Load/entry address | `$0100` |

This is host-model evidence. It is not a physical-machine or ESP32
measurement.
