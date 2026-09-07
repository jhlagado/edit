# Native visible frame audit

Passed 31 reference-image audits, including one cold edit and 30 warm keys. Every image contains a unique visible gray cursor in the expected first-row column. Decoded first-match and reference pixels agree across the entire window. Public Terminal contents, raw mach timestamp conversions and earliest matching captured frames also agree.

Warm presentation median: **50.716 ms**; p95: **73.234 ms**. This is a captured WindowServer presentation bound under instrumentation, not physical-panel or uninstrumented host latency.

Complete captured frames: 589. Median frame interval: **31.579 ms**, maximum **66.555 ms**. Callback delay median: **178.064 ms**, p95 **186.733 ms**. Callback delay is separate from the presentation timestamp; capture and PNG encoding can still affect host execution.

Calibration: 1160 × 770, first cell x=20, pitch=14, cursor y=78–105. The pixel test uses the calibrated band above glyph ink. Other dimensions are rejected unless explicit calibration arguments are supplied. The contact sheet retains the text and cursor evidence for visual review.

The private disk, extracted physical EDIT records, frozen artifact and native executable hashes passed verification against `provenance.json`. Cleanup confirms native stop, capture stop and closure of the dedicated window, with no recorded errors. See `audit.json` for raw audit results and provenance, and `cursor-audit-contact.png` for all reference rows.
