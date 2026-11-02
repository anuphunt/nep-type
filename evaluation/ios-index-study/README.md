# iOS index packing research — not integrated

**Status:** Research only. The shipping iOS project continues to bundle and read the original, canonical TSV indexes. The packed reader and generator are not compiled into the keyboard, and no raw resource was removed. This experiment does not change the data's provenance or resolve redistribution/commercial rights.

## Lossless representation and verification

`pack-index.py` groups strictly byte-sorted, newline-terminated TSV rows into at most 65,536-byte blocks and zlib-compresses each block independently. The directory stores the first ASCII key, payload offset and compressed/uncompressed sizes; the header includes source SHA-256. No candidate or ordering is intentionally changed. The prototype `PackedIndex.swift` memory maps the packed file, binary-searches block keys, decompresses one block, binary-searches it, and validates rows using the current shared reader's rules: terminated row at most 4,096 bytes, at most 64 nonempty candidates, at most 60 Unicode scalars per candidate, with only Devanagari and ZWJ/ZWNJ. It returns no candidates on a malformed row or failed block decode. A production adapter, user-visible error reporting, format version evolution and corrupt/missing-resource fallback are **not implemented**; a bad block can affect all keys in that block. Runtime does not recompute the header SHA-256 for the whole file, so this is not an authenticity guarantee.

For the current exact source data:

| Index | Raw bytes | Packed bytes | Rows | Blocks |
|---|---:|---:|---:|---:|
| Google aliases | 10,618,399 | 1,211,576 | 278,253 | 163 |
| Aksharantar | 98,652,429 | 18,324,907 | 2,171,523 | 1,506 |
| Total | 109,270,828 | 19,536,483 | 2,449,776 | 1,669 |

That is 89,734,345 fewer **uncompressed resource-file bytes**, about 82.1%; it is not an actual `.ipa` download-size, device-storage, extension-memory or energy measurement. The manifests record source/packed hashes. An exhaustive Python check decompressed every block and compared every source byte and row in order. An optimized Swift comparison called both current raw and packed readers for **every one of the 2,449,776 existing keys** and returned identical candidate arrays; an additional 8,258 boundary/sample/absent-key check also passed. This does not prove behavior for all possible corrupt/malicious files, interleavings, runtime/OS versions or candidate-ranking/host behavior. Corruption checks cover bad magic, oversized directory, truncation, damaged block checksum, invalid UTF-8, ASCII/empty/overlong/too-many candidates, oversized row and builder refusal of an unterminated row. Unlike a production fallback, prototype lookup returns an empty list when a packed block fails.

The canonical raw reader source SHA-256 at test time was `0b41ac173a379c343d7be41359928cc4d7938968c57bb093064536360b1a96de`. If its validation or index data changes, these checks must be redone and the isolated reader updated. `google-pack-manifest.json` and `mined-pack-manifest.json` include resource hashes; compiled packed data is intentionally not retained here, and can be regenerated locally from already-authorized source TSVs.

## Performance and memory — exploratory only

A small optimized macOS CLI benchmark ran 10 separate processes per mode, 2,000 direct mined-index lookups each across ten repeated keys. OS page cache was not cleared. Median warm per-lookup p95 was 0.0080 ms raw vs 0.0381 ms packed; median process maximum RSS was 10,125,312 vs 9,289,728 bytes. Packed initialization plus first lookup had median 0.391 ms, vs 0.464 ms for raw's lazy initialization plus first lookup. These small hot-cache direct-lookup samples are neither iOS performance nor representative typing; they include no UI, context ranking or both indexes simultaneously. See `bench-results.json`.

A temporary standalone **iOS Simulator app, not a keyboard extension**, ran three fresh processes per mode on a booted iPhone 17 Pro/iOS 26.2 simulator, using the same ten repeated keys and current canonical corrupt-row validator. App was removed afterward; no input source was installed or enabled. Median initialization plus first lookup was 0.205 ms raw vs 0.345 ms packed; median of per-process warm p95 was 0.0086 ms vs 0.0399 ms. Median process RSS change from pre-lookup to after 2,000 lookups was about 1,785,856 bytes raw vs 933,888 packed, while median `phys_footprint` change was 81,992 bytes raw vs 262,168 packed. Absolute simulator RSS baselines exceeded 200 MB, OS cache was not cleared, samples were sequential and only three per mode; the mixed results **do not establish an iOS extension memory reduction**. `Simulator/raw-*.json` and `Simulator/packed-*.json` retain individual measurements. Device jetsam, many different pages, thread scheduling, startup, energy, cold disk, actual extension packaging and host typing remain unmeasured.

## Reproduction and risk

From this directory, `./run-parity.sh /path/to/Lekha /tmp/new-empty-lekha-pack-study` packs both local TSVs, compares every source byte and key lookup, and exercises malformed inputs; it requires macOS Xcode/Swift and takes time. It refuses to overwrite an existing scratch path. `benchmark.py` and `Bench/main.swift` reproduce the macOS direct-lookup experiment after compilation; `Simulator/run.sh` creates a temporary standalone simulator app only when explicitly invoked with a booted device, project path and a packed mined-index file. It installs no keyboard, refuses an existing test-app ID, and uninstalls its temporary host afterward. Simulator use requires the appropriate user/environment authorization.

Before considering integration: design a versioned, authenticated or integrity-checked resource strategy; specify safe missing/corrupt behavior and user feedback; validate independent OS/runtime and native extension/device behavior; measure latency, real memory, package size and energy on representative workloads; verify candidate coverage/ordering against changed indexes and production validation; and review current data licenses. Do not silently replace the TSV or claim memory savings based on this exploratory test.
