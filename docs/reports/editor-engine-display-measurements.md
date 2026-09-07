# Editor engine milestone 3: display measurements

8 September 2026. These are complete-command Z80 measurements using ATOM and the development CPU runtime. Fake BDOS service cycles are excluded; terminal bytes and storage operations are separate counts. Host measurements are in the [host qualification report](editor-engine-host-qualification.md).

The incremental renderer reduces repeated output and traversal. Warm long-line work is bounded by the visible rows and columns, but full horizontal repaint remains expensive. The proposed 100,000-T-state target is retained and misses are reported per command. No nominal-clock conversion is an input-to-visible latency measurement.

## Reproduction and identity

Run `npm run measure:display` from the Edit repository. It rebuilds the candidate with ATOM and writes [the raw report](editor-engine-display-workloads.json). `npm run check` includes this comparison, the earlier measurement suites, and the behavioural proofs. The raw report retains all per-key counters, viewport changes, observable hashes, setup costs, runtime identity and source hashes for the runtime. The [frozen candidate](../../test/fixtures/editor-engine-milestone3.json) records the measured binary and production source hashes.

| Artifact | COM bytes | Workspace | Text bytes | SHA-256 |
| --- | ---: | ---: | ---: | --- |
| original | 3,107 | 297 | 47,104 | `73265438a4f2df9a3f507f1bdcd49c48ebabe46cbcdb96e58dc0ee39f8b6a905` |
| milestone1 | 3,872 | 338 | 47,104 | `7b03e6ae7ae307def988460151bbea37c2a1d3caff7719edd4f09dd56b197fa1` |
| milestone2 | 4,050 | 342 | 47,104 | `28a001d1a8644de563f4abe01133f7ad4ec004de8649f64f9c85b1fd13b1ea45` |
| current | 5,513 | 490 | 47,104 | `6be83f6edb9ee92387c7b3817f473fbbc389a58ab1a20d9a2a6101e695fb77c4` |

The current artifact has 3 entry bytes, 5,297 code bytes and 213 immutable bytes. It leaves 1,911 code-partition bytes and 22 fixed-workspace bytes unused. The private stack reservation remains 3,072 bytes. No cache uses the text arena or a hidden host allocation. Actual entry/command execution reaches at most 24 bytes below the private stack top in this suite. Direct-routine fixtures deliberately start their stack 258 bytes below that top, yielding a maximum reported distance of 274 bytes (16 bytes below the fixture starting SP). That distance is not 274 bytes of routine stack consumption. Separate entry/rollback proofs remain part of the owner check.

## Cold edit and warm typing

Each fixture loads through the real entry path. Cursor placement and explicit setup repaint are separately recorded and excluded from command counters. The first edit includes gap relocation. Subsequent keys run from one main-loop input boundary through the next, including semantic editing, layout and terminal output. Every stage and every warm key must match the original, milestone-one and milestone-two logical state, cells, attributes, cursor, bell and disk digest.

| Workload | M2 cold T-states | M3 cold T-states | M2 warm mean | M3 warm mean | Change | Warm terminal bytes/key M2 → M3 | ≤100,000 keys |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| cold-and-warm100-16384-beginning | 749,189 | 406,096 | 487,159 | 182,002 | -62.6% | 600.4 → 198.1 | 47/100 |
| cold-and-warm100-16384-middle | 693,494 | 271,069 | 599,589 | 205,164 | -65.8% | 582.4 → 217.6 | 18/100 |
| cold-and-warm100-16384-end | 514,348 | 84,406 | 584,976 | 228,790 | -60.9% | 523.4 → 260.4 | 30/100 |
| cold-and-warm100-40960-beginning | 1,265,285 | 922,192 | 487,159 | 182,002 | -62.6% | 600.4 → 198.1 | 47/100 |
| cold-and-warm100-40960-middle | 922,268 | 505,563 | 570,619 | 202,339 | -64.5% | 548.6 → 219.0 | 37/100 |
| cold-and-warm100-40960-end | 485,578 | 63,768 | 568,001 | 180,171 | -68.3% | 563.8 → 186.7 | 46/100 |
| cold-and-warm100-46848-beginning | 1,388,933 | 1,045,840 | 487,159 | 182,002 | -62.6% | 600.4 → 198.1 | 47/100 |
| cold-and-warm100-46848-middle | 1,048,595 | 606,298 | 606,526 | 274,791 | -54.7% | 449.4 → 341.3 | 6/100 |
| cold-and-warm100-46848-end | 539,454 | 102,120 | 597,292 | 258,550 | -56.7% | 475.8 → 312.6 | 16/100 |
| distant-search-then-first-edit-16384 | 720,594 | 401,891 | 563,241 | 182,000 | -67.7% | 561.0 → 190.1 | 43/100 |
| long-printable-cold-warm8 | 18,493,152 | 357,312 | 18,327,986 | 185,031 | -99.0% | 235.0 → 411.0 | 0/8 |
| long-tabs-cold-warm8 | 28,747,038 | 223,362 | 28,666,873 | 140,644 | -99.5% | 235.0 → 411.0 | 0/8 |
| horizontal-23-rows-200 | 4,052,676 | 1,826,449 | 4,007,248 | 1,777,669 | -55.6% | 1,996.0 → 2,106.0 | 0/8 |
| horizontal-23-rows-1600 | 29,389,876 | 2,164,549 | 29,006,348 | 1,777,669 | -93.9% | 1,996.0 → 2,106.0 | 0/8 |

For the distant-search workload, the first two columns above are the initial gap-establishing edit; the search and first distant edit are separately listed below. Warm populations contain 100 keys for source fixtures and eight for pathological long-line cases. Means describe total work; they do not replace the maximum and per-key target results below. All warm gap candidates copy zero text-tail bytes.

| Workload | Maximum warm T-states | Unchanged-viewport keys | Maximum with unchanged viewport | Maximum scalar text reads/key |
| --- | ---: | ---: | ---: | ---: |
| cold-and-warm100-16384-beginning | 659,521 | 78 | 129,531 | 730 |
| cold-and-warm100-16384-middle | 637,680 | 76 | 139,983 | 700 |
| cold-and-warm100-16384-end | 637,776 | 62 | 140,440 | 699 |
| cold-and-warm100-40960-beginning | 659,521 | 78 | 129,531 | 730 |
| cold-and-warm100-40960-middle | 631,056 | 72 | 139,983 | 692 |
| cold-and-warm100-40960-end | 637,776 | 78 | 140,440 | 699 |
| cold-and-warm100-46848-beginning | 659,521 | 78 | 129,531 | 730 |
| cold-and-warm100-46848-middle | 637,680 | 40 | 139,983 | 700 |
| cold-and-warm100-46848-end | 637,776 | 48 | 140,440 | 699 |
| distant-search-then-first-edit-16384 | 629,184 | 78 | 139,287 | 688 |
| long-printable-cold-warm8 | 185,031 | 0 | 0 | 169 |
| long-tabs-cold-warm8 | 142,341 | 0 | 0 | 45 |
| horizontal-23-rows-200 | 1,777,669 | 0 | 0 | 2,084 |
| horizontal-23-rows-1600 | 1,777,669 | 0 | 0 | 2,084 |

The viewport policy is unchanged: once the cursor reaches column 80, further insertion moves the horizontal origin and repaints every visible row. This can make a growing ordinary line cross from one-row work into full repaint during a single burst. Target failures also occur before that transition on sufficiently long visible rows; the implementation does not claim that every unchanged-viewport edit meets 100,000 T-states.

The 23-row fixtures differ only in hidden line length. Equal warm scalar-read and T-state counts across widths 200 and 1,600 demonstrate that repeated horizontal shifts do not traverse those unchanged prefixes. The display proof separately compares 2-KiB and 16-KiB printable and tab-heavy lines, with explicit scan limits and exact full-render state comparison.

## Read, search, save and exceptional movement

| Workload / stage | M2 T-states | M3 T-states | Change | M3 scalar reads | M3 terminal bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| distant-search-then-first-edit-16384 / establish-gap-at-beginning | 720,594 | 401,891 | -44.2% | 14 | 117 |
| distant-search-then-first-edit-16384 / far-search-without-relocation | 126,625,605 | 132,222,070 | +4.4% | 401,406 | 1,445 |
| distant-search-then-first-edit-16384 / first-edit-after-far-search | 824,957 | 412,114 | -50.0% | 14 | 119 |
| read-layout-search-16384 / move-right-left-without-relocation | 792,821 | 15,604 | -98.0% | 9 | 12 |
| read-layout-search-16384 / find-across-gap-without-relocation | 59,414,982 | 62,284,659 | +4.8% | 196,109 | 1,454 |
| read-layout-search-16384 / full-render-without-relocation | 485,534 | 770,891 | +58.8% | 1,385 | 736 |
| save-cross-gap-8191 / save-without-relocation | 541,865 | 175,922 | -67.5% | 3 | 101 |
| save-cross-gap-8192 / save-without-relocation | 534,792 | 168,849 | -68.4% | 3 | 101 |
| save-cross-gap-8193 / save-without-relocation | 541,837 | 175,894 | -67.5% | 3 | 101 |
| backward-tab-after-long-prefix / left-across-tab-cold | 26,091,107 | 5,757,447 | -77.9% | 16,555 | 411 |
| backward-tab-after-long-prefix / right-across-tab | 26,091,869 | 185,255 | -99.3% | 172 | 413 |
| backward-tab-after-long-prefix / left-across-tab-repeat | 26,091,107 | 5,757,504 | -77.9% | 16,555 | 411 |

Read-only operations assert unchanged physical gap bounds and zero text-arena writes. Save can copy into the existing DMA record without relocating the gap. Cold discovery and search may still inspect substantial document text. During qualification, far search initially regressed by about 136% because discovery repeatedly probed an obsolete viewport cache. Clearing cache validity before the cold walk removed that redundant work. The remaining increase reflects cache miss checks and cold cache construction, rather than a change to search or saved text. Moving the horizontal origin backward into a tab can scan the printable run before that tab to recover its exact starting column; the repeated backward-tab workload deliberately exposes that cost. The cursor itself is 79 printable cells beyond the tab, so this is anchor recovery, not a cursor byte jump across the tab. This is an explicit navigation limitation, not a repeated-typing cache claim.

## Entry and cold layout

| Bytes / cursor | M2 entry T-states | M3 entry T-states | M2 fixture repaint | M3 fixture repaint |
| --- | ---: | ---: | ---: | ---: |
| 16384-beginning | 6,692,827 | 7,652,230 | 394,186 | 684,100 |
| 16384-middle | 6,692,827 | 7,652,230 | 53,423,109 | 56,294,928 |
| 16384-end | 6,692,827 | 7,652,230 | 109,088,230 | 114,662,432 |
| 40960-beginning | 16,133,587 | 18,100,606 | 394,186 | 684,100 |
| 40960-middle | 16,133,587 | 18,100,606 | 136,977,788 | 143,907,249 |
| 40960-end | 16,133,587 | 18,100,606 | 276,468,652 | 290,186,730 |
| 46848-beginning | 18,395,476 | 20,603,903 | 394,186 | 684,100 |
| 46848-middle | 18,395,476 | 20,603,903 | 156,905,015 | 164,813,522 |
| 46848-end | 18,395,476 | 20,603,903 | 316,400,661 | 332,071,677 |

Entry includes parsing, loading and first display, so these are not isolated loader timings. Explicit forced repaint invalidates caches and therefore includes fresh boundary discovery. Its cost must not be confused with a warm incremental command. Earlier raw reports remain historical records and were not overwritten.

## Interpretation

The structural milestone gates are separate from the proposed numerical targets. Cursor-only commands paint no text rows, same-line edits with unchanged view paint only their row, and warm long-line typing does not repeat hidden traversal. Code and workspace remain within their original partitions. The numerical CPU target is not uniformly met; it remains an unmet target rather than being relaxed to make this report pass. Native/browser presentation measurements likewise retain their boundaries and misses in the host report. Further reduction of full-row output cost or a changed horizontal-follow policy would require additional work; the latter would change user-visible behaviour.
