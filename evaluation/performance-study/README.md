# Offline engine performance diagnostic

This is a local, read-only input benchmark of the **debug** JSON-lines portable-core test executable on the development Mac, not the production app, a system keyboard, a release binary, or an iOS/Android device. It creates no user preferences and does not enable or install an input source. No network traffic is needed by the test. The two index paths are set explicitly; the missing-index scenario uses explicit nonexistent paths, avoiding accidental bundle fallback. `/usr/bin/time -l` process statistics required local execution outside the restricted sandbox on this Mac.

## Environment and method

- Apple M4 Max, 64 GiB memory, macOS 26.6.2, arm64; Apple Swift 6.4.
- The debug executable used was `/tmp/neptype-portable-build/debug/neptype-conformance`, SHA-256 `d1095c80487beb35311a6981aaee835864e55e0f1e1f74f52abbd36e3564327c`. All five portable core source files byte-matched the current project; its Transliterator source (`7c18905dabbe524c76a2908ca17231f277233adae0ad25f1de6c60badaed9540`). This process is a test transport, not a stable production API.
- Google alias index: 10,618,399 bytes. Aksharantar index: 98,652,429 bytes. Both are memory-mapped by the engine where available; total index files are 109,270,828 bytes (104.2 MiB). SHA-256 values: Google `87a19947eb60a7ac495b675aae980c94b977598cd11874c7b9b23e5d4b42f159`, Aksharantar `a62c90b709c425f78e9b0ffcbb263823e38a3cb3c2f2286d64ecdaaa9b52970d`. Original source rights and redistribution remain unresolved as documented in the project.
- Ten fresh processes per condition. Filesystem/OS page cache was **not cleared**; fresh process is not a cold-disk test. Each sends one initial `bhaisakeko` lookup then repeats ten words 20 times. First lookup initializes more engine state than the empty session. Request timings include process pipe transport, JSON parsing/encoding, state/candidate serialization and scheduling; they are not a single internal index lookup or typing latency. Repeated words are a small hot working set.
- `/usr/bin/time -l` reports each wrapped process's maximum resident set size and peak memory footprint; the latter is macOS-specific and is not interchangeable with RSS. Memory-map pages are demand-loaded. These runs touch a tiny subset of the indexes and do not estimate worst-case resident memory, multi-app use, iOS extension memory or battery.

## Observed results

| Measure | Indexes present | Explicit missing paths |
|---|---:|---:|
| Fresh process to empty session, median (10 processes) | 6.50 ms | 5.96 ms |
| First `bhaisakeko` request, median (10 processes) | 47.44 ms | 42.72 ms |
| Later request median / p95 (2,000 requests) | 0.383 / 0.669 ms | 0.192 / 0.258 ms |
| Maximum RSS, median (10 processes) | 42,311,680 bytes (40.35 MiB) | 39,550,976 bytes (37.72 MiB) |
| Peak memory footprint, median (10 processes) | 24,830,600 bytes (23.68 MiB) | 23,986,668 bytes (22.88 MiB) |

The first `bhaisakeko` candidates were `भैसकेको`, `भइसकेको`, and the original with indexes. With explicit missing paths they were `भैसकेको` and the original; the indexed alternative was unavailable, but the process remained functional. This is one fallback check, not evidence that all missing/corrupt files or candidate paths are safe. The full individual summary, p95/min/max and index-presence checks are in `results.json`.

With only ten processes, process-level p95 is the maximum sample under the nearest-rank method; it is not a reliable tail estimate. The two conditions ran sequentially, so cache, other system activity and ordering can confound comparisons. Do not infer release performance or guaranteed timing from the small differences. UI responsiveness, cold-disk behavior, iOS extension jetsam, Android memory, failures, battery and real cross-application keyboard input still need platform tests.

## Repeat

From the NepType project root, first build the portable test executable with the documented `portable-core/README.md` instructions. On macOS, allow access to local process memory statistics if the execution environment requires it, then run:

```sh
python3 evaluation/performance-study/bench.py \
  --executable /path/to/neptype-conformance \
  --alias-index "$PWD/data/compiled/google-ne-aliases.tsv" \
  --mined-index "$PWD/data/compiled/aksharantar-indiccorp-v1.tsv" \
  --runs 10 --rounds 20 > results.json
```

The script uses `/usr/bin/time -l`, so it is Mac-specific. It does not clear caches or use administrative commands. Keep results distinct by build, machine and date; ensure the executable and core hashes correspond to the version being measured.

## Optimized test-harness follow-up

The same portable test harness was also built with `swift build -c release` (SHA-256 `e71e367d283d36a728e849eae7c3723bdceba3958742db1e03bf7c9cbf5fff24`) and the same 10 fresh-process, 200 repeated-word requests per process protocol. This is an optimized **test harness**, not a signed production build or native input-method measurement. `release-results.json` has the full results.

| Measure | Indexes present | Explicit missing paths |
|---|---:|---:|
| Fresh process to empty session, median | 5.28 ms | 5.34 ms |
| First lookup, median | 17.86 ms | 17.17 ms |
| Later IPC request, median / p95 (2,000) | 0.191 / 0.268 ms | 0.148 / 0.182 ms |
| Maximum RSS, median | 41,811,968 bytes (39.88 MiB) | 39,337,984 bytes (37.52 MiB) |
| Peak memory footprint, median | 23,912,976 bytes (22.81 MiB) | 23,945,720 bytes (22.84 MiB) |

One indexed fresh-process startup sample was **256.88 ms**; nearest-rank p95 for ten processes is that maximum. The cause is unknown; do not discard it, or assume it establishes a typical p95. OS cache and machine load were not controlled; conditions were run sequentially and this follow-up was run after the debug experiment. The process-level numbers therefore are not a controlled performance comparison. As in the debug run, the `भइसकेको` alternative was present in all ten indexed runs and absent in all ten explicit-missing runs.

For repeat runs of the optimized harness pass `--build-type release`; the measurement mechanics are otherwise identical.

## Post-validation debug diagnostic

After adding structural bounds and Devanagari-only candidate validation, the same debug transport was sampled in five fresh processes per condition, again with OS cache not cleared. With indexes, median first lookup was 44.63 ms, later request median/p95 0.352/0.608 ms over 1,000 requests, and median maximum RSS 42,123,264 bytes. These runs occurred later and are not paired or controlled against the earlier ten-process measurement; they do not establish a performance improvement or regression. `post-validation-debug.json` contains the samples. This test exercises only a small hot working set and does not verify native host latency or worst-case memory.
