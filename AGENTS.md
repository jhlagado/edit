# Edit development rules

- Use ATOM for every normal assembly, build, test, and release path.
- Do not add AZM as a dependency or executable oracle.
- Keep the production Z80 program independent of Triptych and Debug80.
- Debug80 Runtime may be used only by tests and development tools.
- Preserve the guest-visible editor and BDOS contracts in
  `docs/specification.md`.
- Run `npm run check` before handing off changes.
- Distinguish headless host-model proof from physical-hardware measurement.
