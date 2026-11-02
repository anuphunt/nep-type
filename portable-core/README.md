# Portable protocol compatibility harness

The production JSON-lines executable is now Rust, built from `engine/src`:

```sh
bash scripts/build-shared-engine.sh
python3 portable-core/tests/conformance.py build/shared-engine/neptype-conformance
python3 portable-core/tests/safety_corpus.py build/shared-engine/neptype-conformance
```

Linux IBus can use that executable through its existing asynchronous transport.
It uses the exact same embedded dictionary and session implementation as the
native C ABI, Apple interfaces and website. No Swift runtime or external TSV
paths are needed. The old `NEPTYPE_ALIAS_INDEX` and `NEPTYPE_AKSHARANTAR_INDEX`
variables cannot change its dictionary.

The Swift package in this directory remains a thin compatibility test client:
it re-exports the parent package's Rust-backed `NepaliCore` types. There are no
copied language algorithms or checked-in dictionary snapshots. Build the Rust
host archive first, then use `swift build --package-path portable-core` if that
Swift compatibility executable is required.

The line protocol supports create/state/append/backspace/cycle/select/commit,
cancel/reset/set_language/destroy. Every session owns its composition state;
mode changes and destruction reject pending composition until it is explicitly
committed or cancelled. Requests and responses are local process communication,
not a network service. Native clients must still enforce host editor ownership,
stale-response rejection and secure-field policy. See [shared architecture and
verification](../shared/README.md).
