# Varied local index-path benchmark

This is a deterministic **implementation and hot-cache diagnostic**, not a transliteration-accuracy, user-population, Android-device or real keyboard benchmark. It runs no input method, uses no network and changes no system settings. The 3,000 sampled rows and candidate strings are derived directly from the same Aksharantar index under test; they are not independent correctness labels. Source and redistribution rights for that dataset remain unresolved before distribution.

`generate.py` streams the current sorted TSV, makes a seeded reservoir sample of 3,000 existing keys and exact candidate lists, verifies 200 generated long ASCII keys are absent from the index, and adds seven malformed/non-key controls. `workload.json` and `workload.tsv` hold the resulting 3,207 queries; order is deterministically shuffled and repeated for three passes. Each lookup is timed inside one process, excluding fixture parsing, compilation, and output serialization; the first Swift lookup includes lazy index initialization. The first pass may fault in pages, but the OS page cache was not cleared and multiple prior scans/runs occurred. Machine contention, filesystem caching, Java JIT, runtime warm-up and run order were not controlled. The results are neither cold-disk nor startup nor battery nor native host latency.

The observed run was on macOS 26.6.2 arm64, Apple Swift 6.4 with `swiftc -O`, and Homebrew OpenJDK 27 running Java 8 bytecode. Swift tested `GeneratedAliasIndex.aksharantarLookup` with its current shape validation; Java tested the Android `SortedCandidateIndex` directly on an ordinary local TSV file, **not** on an APK asset or device. The implementations/languages differ and these numbers should not be used as a head-to-head platform performance comparison.

| Path and query group | Samples | Median | p95 | p99 | Max |
|---|---:|---:|---:|---:|---:|
| Swift, indexed keys | 9,000 | 0.007916 ms | 0.010542 ms | 0.012667 ms | 0.562500 ms |
| Swift, verified absent keys | 600 | 0.005583 ms | 0.006459 ms | 0.007667 ms | 0.010958 ms |
| Java, indexed keys | 9,000 | 0.015292 ms | 0.023125 ms | 0.053333 ms | 2.027333 ms |
| Java, verified absent keys | 600 | 0.012708 ms | 0.018250 ms | 0.041083 ms | 0.059916 ms |

All results matched the index-derived exact ordered lists, and all verified-absent/invalid controls returned an empty list. This verifies implementation consistency for these samples, **not** whether the listed spellings are correct, privacy of host apps, candidate ranking, memory pressure, or corrupted-index safety. `swift-results.json`, `java-results.txt`, workload and `SHA256SUMS.txt` record the results and source/data snapshots. Invalid-control distributions contain only 21 observations and are not meaningful tails. The maximum values are retained; p99 here is within-process and cannot predict user-facing latency.

## Repeat from the NepType project root

Set `JDK_BIN` to an already installed JDK bin directory and run:

```sh
JDK_BIN=/path/to/jdk/bin ./evaluation/index-benchmark/run.sh
```

The script creates a unique temporary directory, streams the local index, compiles a Swift executable and Java test into that temporary directory, runs both, then removes its own temporary files. It requires the Swift toolchain, Python 3 and JDK; it installs nothing. Results will differ with OS cache, workload, runtime and hardware. Compare current source/index hashes with `SHA256SUMS.txt` before interpreting this recorded snapshot. No dataset frequency is inferred from candidate order.
