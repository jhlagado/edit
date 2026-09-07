# Editor host qualification

Host qualification measures a keystroke through the real standalone editor and its host display path. It complements the deterministic Z80 instruction, T-state and terminal-byte measurements. Fake BDOS execution cannot establish host input latency, browser rendering time or native terminal presentation time.

This record documents the final frozen-M2/M3 comparison, qualified on 8 September 2026, and the initial runs that established the probes. Both candidates ran through the actual standalone host paths. Numerical target misses and observation limits remain explicit.

## Measurement boundaries

Each result retains its start and completion boundary. The four reported intervals must remain separately labelled.

| Metric | Start | Completion | Scope |
| --- | --- | --- | --- |
| Native PTY output | Monotonic timestamp immediately before writing one input byte to the native host's PTY | Receipt of the complete final ANSI cursor-position command for that edit | Native execution and output transport; terminal drawing is excluded |
| Native captured presentation | Mach timestamp immediately before the bridge writes the input byte to the native host's PTY | `displayTime` of the first captured complete frame matching the settled rendered result | Apple Terminal rendering and WindowServer presentation in the instrumented run |
| Browser DOM | Browser-local `performance.now()` in a capturing listener for the real terminal keyboard event | Exact expected first-row text and final cursor attributes after DOM replacement | Keyboard dispatch, WASM execution, serial draining, terminal model update and DOM construction |
| Browser next frame | The same keyboard-event timestamp | The animation-frame callback following the matching DOM result | A frame opportunity after DOM completion; physical presentation is not verified |

ScreenCaptureKit's `SCStreamFrameInfoDisplayTime` uses mach absolute time for the frame's WindowServer display event. The native capture report uses that timestamp, converted with `mach_timebase_info`. Callback arrival and PNG persistence occur later and have separate timestamps. Neither this timestamp nor the browser animation-frame callback measures physical monitor scanout.

Native input starts at the PTY bridge. It excludes physical keyboard hardware and macOS keyboard dispatch. Browser input starts at the dispatched keyboard event, also excluding physical keyboard hardware. Comparisons between editor artifacts are meaningful within one of these boundaries; ratios between different boundaries do not isolate editor performance.

## Workload and statistics

The private disk contains `INPUT.TXT`, a 16,384-byte repetition of `ordinary source line 0123456789` followed by CRLF. Each session starts the real `EDIT INPUT.TXT` command at the CP/M prompt. Loading, initial drawing and launch time are outside the per-key sample population.

The first inserted `x` is recorded separately as the cold edit. Thirty further insertions, `a` through `z` followed by `a` through `d`, form the warm population. The cold edit is excluded from the warm median and p95. This sequence measures ordinary typing near the beginning of a populated document, including the first gap relocation for M2. It does not qualify far-jump editing, scrolling, search, save or long-line behavior; those require their own workloads and final-state checks.

The tools accept 30–60 warm samples. This bound keeps the expected text and cursor on the first 80-column row. A sample completes before the next key is sent. The native visible probe also allows the result to settle before selecting its reference image; it then uses the earlier matching frame's timestamp for latency. Settling time is outside the reported interval, but the resulting cadence differs from continuous physical typing.

For an even sample count, the median is the mean of the two middle sorted values. The p95 uses the nearest-rank value at `ceil(0.95 × sample_count)`, which is the 29th sorted observation for 30 samples. Reports retain every raw sample. One short run does not establish a stable tail distribution; qualification comparisons should retain repeated runs and their order when variability affects the decision.

## Private artifacts and host prerequisites

All probes execute an editor binary selected from a frozen artifact JSON containing `binaryBase64`, its byte count and SHA-256. Production editor binaries must be assembled with ATOM. The preparation command verifies the binary hash, installs those bytes into a private copy of Triptych's small CP/M disk through the public `installCpm22File` function, and reads `EDIT.COM` back to check the installed bytes. CP/M record padding is distinct from the executable byte count.

The base image is Triptych's existing `dist/wasm-browser/cpm22.img`. The copied image includes the existing resident system, with only the private editor and workload files replaced. There are no release-pin updates, published artifacts or IDE integration steps. Each run uses its own output directory and disk. Native sessions use `TRIPTYCH_CPM22_WORK_DISK`, whose saved-image path preserves the disk bytes. The native `TRIPTYCH_CPM22_IMAGE` source-copy path reinstalls the pinned EDIT release and is therefore unsuitable for this measurement.

The browser server has different override behavior: its `TRIPTYCH_CPM22_IMAGE` setting serves the supplied private disk directly. The browser probe starts this server on `127.0.0.1`, uses a disposable browser context and closes both afterward. Saved disks in the user's normal browser profile are outside this path.

Required installed components are Node.js, Python, Triptych's built native host and browser assets, and Triptych's Playwright installation with a Chromium browser. The initial browser runs used headed Chromium 151.0.7922.34 on arm64 macOS. Native visible capture additionally requires Swift, the macOS SDK with ScreenCaptureKit, and Apple Terminal. The initial captured run used Terminal 2.15, build 470.2, on macOS 26.5.2.

The visible probe requires existing screen-capture and Terminal automation grants for its actual execution context. Nonprompting preflight checks run before use; the tools do not request or change permissions. An automation result of `-600` can mean Terminal is not running. Starting Terminal explicitly and repeating the preflight distinguishes that case from a missing grant. A grant observed from another process does not prove access for the capture runner.

## Reproduction

These commands use explicit checkout and output paths. Set the four paths for the local machine. `QUAL_ARTIFACT` initially selects frozen M2; select the final candidate's frozen artifact for the paired candidate run. Use a new `QUAL_OUTPUT` for every artifact and repetition so that earlier evidence remains intact.

```sh
EDIT_ROOT=/absolute/path/to/edit
TRIPTYCH_ROOT=/absolute/path/to/triptych
QUAL_ARTIFACT="$EDIT_ROOT/test/fixtures/editor-engine-milestone2.json"
QUAL_OUTPUT=/absolute/path/to/qualification/m2-run-1
mkdir -p "$QUAL_OUTPUT"
```

The preparation-only command creates `private.img` and `private-disk-provenance.json` without launching a server or browser:

```sh
node "$EDIT_ROOT/tools/qualify-editor-hosts.mjs" \
  --triptych "$TRIPTYCH_ROOT" \
  --artifact "$QUAL_ARTIFACT" \
  --output "$QUAL_OUTPUT" \
  --prepare-only
```

The headed browser command rebuilds the same private disk from the selected frozen artifact, then records 30 warm samples, the cold edit and before/after screenshots. Port 4187 is an example; select an unused localhost port and run only one probe per output directory.

```sh
node "$EDIT_ROOT/tools/qualify-editor-hosts.mjs" \
  --triptych "$TRIPTYCH_ROOT" \
  --artifact "$QUAL_ARTIFACT" \
  --output "$QUAL_OUTPUT" \
  --samples 30 --port 4187 --headed
```

The native PTY probe uses the prepared private disk and writes its raw report plus an ANSI transcript:

```sh
python3 "$EDIT_ROOT/tools/qualify-editor-native.py" \
  --triptych "$TRIPTYCH_ROOT" \
  --disk "$QUAL_OUTPUT/private.img" \
  --output "$QUAL_OUTPUT/native.json" \
  --samples 30
```

Compile the capture helper into the qualification directory. AppKit initialization is required for this command-line capture process; the helper performs it on the main actor before starting ScreenCaptureKit.

```sh
mkdir -p "$QUAL_OUTPUT/swift-cache"
swiftc -parse-as-library \
  -module-cache-path "$QUAL_OUTPUT/swift-cache" \
  "$EDIT_ROOT/tools/editor-window-capture.swift" \
  -o "$QUAL_OUTPUT/editor-window-capture"
```

With Terminal running and the existing grants confirmed, the visible probe creates a dedicated 80-column, 24-row window. It records frames from that window only and closes that window after the run.

```sh
python3 "$EDIT_ROOT/tools/qualify-editor-visible.py" \
  --triptych "$TRIPTYCH_ROOT" \
  --disk "$QUAL_OUTPUT/private.img" \
  --artifact "$QUAL_ARTIFACT" \
  --capture "$QUAL_OUTPUT/editor-window-capture" \
  --output "$QUAL_OUTPUT/visible" \
  --samples 30
```

For a final M2/M3 pair, finish CPU-intensive owner checks before starting the host runs. Keep the host executable, browser assets, Terminal appearance, window dimensions, display configuration and capture implementation fixed. Record run order and background activity. A change to the editor artifact must not silently become a change to the host or observer. If capture implementation changes, establish a new baseline with that observer.

## Completion checks and frame audit

The browser probe computes the expected first row independently from the preceding row, insertion key and cursor column. Completion requires all 80 expected cells, cursor row 1 and the exact next column. An arbitrary DOM mutation or intermediate cursor position cannot complete the sample. The unchanged public browser app remains responsible for WASM execution and terminal rendering. Its animation-frame callback is recorded after the matching DOM result.

The native PTY probe requires the complete final ANSI cursor-position command for each key. This confirms output completion at the transport boundary. In the visible probe, the bridge forwards those bytes to Apple Terminal; ScreenCaptureKit records complete frames throughout the sequence.

After each key, Terminal's public `contents` property must match the expected first row. The latest settled captured frame becomes the reference. The probe searches the captured frames after the input timestamp for the earliest identical whole-window pixel hash. The reference callback must follow the bridge's completed ANSI output. Comparing the whole window includes the text, cursor, status row and any intermediate redraw effects.

The JSON result remains provisional until its reference images have been audited. The audit must confirm visible glyphs and the cursor at the expected column, compare decoded first-match/reference pixels, and verify that no earlier captured frame after input has the same reference hash. Cursor blink can produce a reference without a visible cursor; such a reference does not qualify a cursor-visible claim. A later matching cursor phase can also lengthen the observation bound.

For the initial M2 run, all 31 images were checked. At the recorded 1160 × 770 capture size, each cursor occupied a unique gray 14-pixel cell beginning at `x = 20 + 14 × (column − 1)`, in the first-row band at y = 78–105. Columns progressed from 2 through 32. Pixel checks and a contact sheet confirmed every position and successive insertion. These coordinates describe that captured Terminal geometry; a changed font, scale or window requires fresh calibration.

## Capture overhead and interpretation

The helper requests 60 frames per second and records only complete ScreenCaptureKit frames. It retains each frame's display, callback and persistence timestamps. The initial M2 run contained 518 complete frames. Its median interval between display timestamps was 33.226 ms, approximately 30 frames per second, with intervals from 9.197 to 207.175 ms. Requested frequency must not be reported as achieved frequency.

Callback delay was substantial: the 30 selected warm-key frames had a median delay of 207.680 ms and p95 246.978 ms after their WindowServer display timestamps. This delay is not hidden inside the reported presentation interval or subtracted as an estimated editor cost. It is reported separately. Capturing and encoding PNGs also adds host load that can affect the editor and terminal while the run is in progress.

The earliest matching captured frame supplies an observation bound. An earlier complete result could have appeared between captured frames. The initial captured p95 of 73.781 ms misses any qualification threshold below that value for this instrumented run. It does not establish an irreducible latency floor for the native host without capture. Lower observer cost requires a newly paired baseline and candidate run, with the same state oracle and retained evidence.

## Initial results

These are initial individual runs, not a final paired M2/M3 comparison. Each row contains 30 warm samples after one separately recorded cold edit. Values are milliseconds.

| Initial artifact | Boundary | Median | p95 |
| --- | --- | ---: | ---: |
| Original, 3,107 bytes | Native PTY output | 10.128 | 18.974 |
| M2, 4,050 bytes | Native PTY output | 9.015 | 9.340 |
| Original | Browser DOM | 15.500 | 17.200 |
| M2 | Browser DOM | 15.300 | 17.300 |
| Original | Browser next frame | 31.650 | 33.700 |
| M2 | Browser next frame | 31.500 | 33.900 |
| M2 | Native captured WindowServer presentation | 52.101 | 73.781 |

The original frozen artifact SHA-256 is `73265438a4f2df9a3f507f1bdcd49c48ebabe46cbcdb96e58dc0ee39f8b6a905`. Frozen M2 is `28a001d1a8644de563f4abe01133f7ad4ec004de8649f64f9c85b1fd13b1ea45`. The initial Triptych revision was `5e2ff4d53a88dafb36125731f0dded913f539c7f`.

| Final paired boundary | M2 median / p95 (ms) | M3 median / p95 (ms) | Interpretation |
| --- | ---: | ---: | --- |
| Native PTY output | 8.842 / 9.799 | 0.837 / 1.013 | Output completion only; excludes terminal painting |
| Native captured WindowServer presentation | 50.716 / 73.234 | 52.417 / 67.277 | Both captured p95 values exceed 50 ms |
| Browser DOM | 15.950 / 17.600 | 15.750 / 16.300 | Exact model/DOM state; not presentation |
| Browser next frame | 32.200 / 33.800 | 32.000 / 32.600 | Below 50 ms at this proxy boundary; physical presentation unverified |

The final artifact is 5,513 bytes with SHA-256 `6be83f6edb9ee92387c7b3817f473fbbc389a58ab1a20d9a2a6101e695fb77c4`. Each row uses 30 warm samples and retains the cold sample. CPU-intensive owner checks were stopped for these final runs. M2 browser/PTY ran first; the final M3 browser/PTY followed the last source correction, then the paired native captured runs. Normal desktop background activity was not disabled. These short runs do not establish a stable tail distribution or a statistically significant native-presentation improvement.

Both final captured runs passed all 31 image audits: visible cursor, expected text, decoded full-window equality, timestamp conversion, earliest matching recorded frame, exact editor/host provenance and successful cleanup. Capture intervals had medians 31.579 ms for M2 and 31.561 ms for M3. Callback-delay medians were 178.064 and 176.924 ms, respectively; p95 values were 186.733 and 196.120 ms. Observer overhead remains separate from the WindowServer timestamp, and may still affect the running host.

The native startup oracle was tightened during qualification. M3 emits an early first-row cursor address while drawing; startup now requires the status hints and the final cursor suffix in the accumulated output, avoiding premature completion at that intermediate address. The failed early-start capture is excluded. Per-key completion and capture timing were unchanged. The successful final M3 run and both audits use exact frozen-artifact verification.

Run the retained image audit after each capture:

```sh
python3 "$EDIT_ROOT/tools/audit-editor-visible.py" --output "$QUAL_OUTPUT/visible"
```

The default audit is calibrated to the recorded 1160 × 770 Terminal geometry. It rejects other sizes unless explicitly recalibrated. [Raw reports and audit records](host-qualification/README.md) retain the numerical evidence and contact sheets.

## Evidence, provenance and cleanup

The browser output directory contains the private disk provenance, `browser.json`, before/after screenshots and server log. The PTY probe writes `native.json` and its `.ansi` transcript. Visible qualification adds `visible.json`, `provenance.json`, `frames/frames.jsonl`, every referenced PNG, capture diagnostics, `live.json` and `cleanup.json`. Audit results and any contact sheet belong beside those raw files.

Current visible-tool provenance verifies the installed editor against the selected frozen artifact and records the private disk hash, physical CP/M record hash, native executable hash, capture-helper hash, qualifier-source hash, Triptych revision, Terminal version and operating system. The browser report records its editor artifact, host assets, browser version and machine metadata. Reports from the initial visible run received a separate post-run provenance audit; that audit explicitly identifies the later verification time and the subsequent provenance-only source additions.

The browser tool owns the local server and disposable browser process and closes both in its cleanup path. The visible probe records its dedicated window and process IDs, sends a stop command through the bridge, awaits native termination, stops capture and closes only the window it created. Failure diagnostics include the helper path, PID, return code and stderr. Existing Terminal tabs and global settings are outside the cleanup scope.

The initial audited M2 capture recorded successful native termination with return code 143, capture termination by SIGTERM, closure of the dedicated window and no cleanup errors. Before accepting any later run, its own cleanup record and artifact identity must be verified rather than inherited from that initial result.
