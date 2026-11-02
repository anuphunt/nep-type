# Lekha portable-core feasibility and conformance harness

This is a **source snapshot of the existing offline Swift engine**, packaged separately from AppKit and InputMethodKit. It builds a Swift library and a JSON-lines executable for testing session behavior. It is an experiment towards a common engine contract, not an independently verified Linux, Windows, Android or iOS library and not a finished keyboard. It makes no network requests. The sources were copied from `lekha-dev/Sources/NepaliCore`; `SOURCE_HASHES.sha256` records the exact snapshot. Changes to the Mac engine do not automatically propagate; reconcile and compare before using this as a product dependency. The current generated data files are not included here. The original project remains authoritative.

On this Mac with Xcode 27.1 and Swift 6, the following builds and tests the core. The two environment paths are optional but necessary to evaluate exactly the same Aksharantar and Google indexes as the Mac engine; if absent, lookup silently falls back to other sources and results may differ. Data provenance/licensing remains in the original project's `data/sources`, including the user-managed Aksharantar commercial review before distribution.

```sh
export CLANG_MODULE_CACHE_PATH=/tmp/lekha-portable-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/lekha-portable-cache
swift build --disable-sandbox --scratch-path /tmp/lekha-portable-build \
  --cache-path /tmp/lekha-portable-spm-cache --config-path /tmp/lekha-portable-config \
  --security-path /tmp/lekha-portable-security
export LEKHA_ALIAS_INDEX="/path/to/google-ne-aliases.tsv"
export LEKHA_AKSHARANTAR_INDEX="/path/to/aksharantar-indiccorp-v1.tsv"
python3 tests/conformance.py /tmp/lekha-portable-build/debug/lekha-conformance
```

`--disable-sandbox` avoids nested sandboxing in this managed environment. It does not install software, access network or change system settings. A normal local Swift build can use the default SwiftPM sandbox where it is available.

## Protocol and safety boundary

The executable reads one JSON object per line and emits one JSON response per line. `id` selects an in-process isolated session; operations are `create`, `state`, `append`, `backspace`, `cycle`, `select`, `commit`, `cancel`, `set_language`, `reset` and `destroy`. A `state` includes original Roman text, candidates, marked text, language and composing flag. `commit` can opt into bounded context with `keepContext` and preserve open backtick literal state across token boundaries with `keepLiteralState`; `cancel` returns the exact original. English mode rejects append so an adapter can pass keys to its host. Invalid operations and unsafe attempts to switch language, reset or destroy while composing return errors; callers must first commit or cancel. No host text is read. There is no state persistence.

A caller must implement OS preedit/marked-text and selection APIs, retain the original keys, map UTF-16 ranges at the host boundary, handle secure fields and focus transitions, and avoid overwriting text it does not own. This line protocol is a test harness, **not** a supported C ABI, Android JNI bridge, IPC security boundary or event-timing design. It uses blocking standard input and writes each response immediately; it is not intended for per-keystroke production use. It has no bounded resource quotas or schema versioning yet.

## Evidence and limitations

- Core and harness built on the local Apple Silicon Mac; 30 protocol requests passed in `tests/conformance.py`, covering multi-session isolation, candidate/original retrieval, context, literal URLs and backtick spans, cancellation, English passthrough and loss guards. This does not independently assess language accuracy or host integration.
- iOS simulator compilation may be possible via SwiftPM/Xcode, but this particular package has not been built or exercised on iOS. Linux and Windows Swift/Foundation compatibility, regular expression behavior, memory-mapped index behavior, packaging, index-resource lookup and performance need native verification. Android requires an independently validated toolchain and bridge; do not assume a supported Swift runtime.
- iOS/Android extensions need explicit resource paths and profiling for the large data indexes. `Bundle.main.resourceURL` and process environment assumptions in the snapshot must be adapted to each host. Do not ship without resource and license checks.
- Conformance fixtures currently cover a small deterministic subset and depend on the same engine implementation; build a versioned, held-out multi-language corpus and compare actual adapters on real platforms before claiming equivalent output. Unicode composition, emoji deletion, cursor/selection, lifecycle, timing, privacy and candidate UI require OS-specific tests.

`tests/safety_corpus.py` adds deterministic raw preservation checks for 511 printable ASCII tokens, including 11 code/URL examples. Run it with the same executable argument and index environment as the conformance script. It tests protocol/session behavior only, not real host selection, undo, secure fields or complete code safety.
