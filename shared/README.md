# Shared offline Rust engine

`engine/src` is the only production implementation of phonetic conversion,
English/Nepali classification, contextual ranking, literal protection, candidate
ordering, document corrections, undo/redo and input-method composition.

| Frontend | Connection |
| --- | --- |
| Website | Rust compiled to WebAssembly, running in a local Web Worker |
| macOS pad and InputMethodKit | Swift value adapters linked to the Rust static library |
| iPhone pad and keyboard extension | The same Swift adapters and a Rust iOS static library |
| Android keyboard | Java → JNI → Rust shared library |
| Linux GTK pad | Python ctypes → Rust shared library |
| Linux experimental IBus | Existing asynchronous JSON-lines transport → Rust executable |
| Windows Win32 pad | C++ → Rust DLL, using the existing serial background worker |

Editor ownership, platform shortcuts, secure-field policy, clipboard access,
stale-result rejection and UI layout stay in the native interfaces. There is no
JavaScript, Java, Swift or Python language-engine fallback. The old Java lookup
fixtures under `platforms/android/tests/legacy` are test-only.

## One embedded dictionary

`engine/data/manifest.json` pins source hashes, pack hash and dictionary ID.
`scripts/build-dictionary-pack.py` builds one lossless pack from the authored
Nepali vocabulary, common English list, pinned CMU membership data, Google
aliases and Aksharantar index. Front-coded blocks and shared Devanagari strings
reduce the original resources to about 37 MB without dropping or reordering
entries. Rust embeds those exact bytes in every native and WebAssembly build.
Native frontends do not load platform-specific TSV snapshots or alternate packs.

The full pack contains 117,493 English forms, 260 authored keys, 278,253 Google
alias rows and 2,171,523 Aksharantar rows. The current fingerprint is returned by
`neptype_dictionary_id`, the Swift `EngineDictionaries.identifier`, Java
`SharedEngine.dictionaryId()`, Python `Engine.dictionary_id`, and WebAssembly's
`dictionaryId()`. A browser worker refuses a module with the wrong fingerprint.

The web build publishes fingerprinted, immutable engine assets and a gzip copy
for the first download. It verifies SHA-256 before loading, caches the engine
locally when browser storage is available, and processes typing in its worker.
The complete vocabulary is available after loading; text is never sent to a
server. Clearing browser storage requires downloading the engine again.

After intentionally changing dictionary sources:

```sh
python3 scripts/engine-data.py refresh
python3 scripts/engine-data.py check
```

Commit the reviewed source and manifest changes. The generated `neptype.pack`
is ignored in Git and rebuilt from the pinned sources. `engine-data.py stage`
packages the manifest and original attribution notices; dictionary bytes already
live in the engine binary. Third-party terms remain in `THIRD_PARTY_NOTICES.md`.

## Build

Install Rust with rustup from https://rustup.rs. `rust-toolchain.toml` and
`Cargo.lock` pin the compiler and dependencies. Python 3 builds the dictionary.

```sh
bash scripts/build-shared-engine.sh      # host library and Rust JSON-lines CLI
bash scripts/build.sh                    # macOS app, static Rust + Swift UI
bash scripts/build-input-source.sh       # build only; never activates an input source
bash scripts/build-web-engine.sh         # WebAssembly and JavaScript bindings
npm --prefix landing-page ci
npm --prefix landing-page run build
```

Host libraries and the Rust `neptype-conformance` executable are staged under
`build/shared-engine`. The website build installs the official Rust toolchain
and pinned wasm-bindgen CLI if they are unavailable, so Netlify Git deployments
build from the same sources. Rust is not required on a visitor's device.

Apple Xcode targets run `scripts/build-apple-engine.sh "$PLATFORM_NAME"` and link
the Rust archive from `build/rust-apple/<platform>`. Device arm64 and universal
arm64/x86_64 simulator libraries are supported. No Swift engine is copied into
the iOS project. Build without signing to check locally:

```sh
xcodebuild -project platforms/ios/NepTypeMobile.xcodeproj -scheme NepTypeMobile \
  -configuration Release -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO build
```

For Android, install an Android SDK/NDK and build each packaged ABI:

```sh
python3 scripts/build-android-engine.py --abi arm64-v8a --ndk /absolute/android-ndk
python3 scripts/build-android-engine.py --abi x86_64 --ndk /absolute/android-ndk
cd platforms/android
gradle assembleDebug
```

The minimum Android API remains 28. JNI uses standard UTF-8 byte arrays. No Swift
SDK or Swift/Foundation runtime is required. Gradle packages the generated Rust
libraries and attribution, and never extracts independent TSV dictionaries.

On Windows, run `python scripts/engine-data.py check`, then
`cargo build --manifest-path engine/Cargo.toml --locked --release`. Copy
`engine/target/release/neptype_engine.dll` into a staging directory as
`NepTypeEngine.dll`, then configure the Win32 project with
`cmake -S platforms/windows -B build/windows -DNEPTYPE_ENGINE_BINARY_DIR=C:/absolute/staging`.
Build and run CTest normally. There is no Swift runtime dependency and no TSF
installation/registration target.

On Linux use `bash scripts/build-shared-engine.sh`, install GTK4/PyGObject, then
run `platforms/linux/run-pad.sh`. The Python client accepts explicit absolute
`NEPTYPE_ENGINE_LIBRARY` and `NEPTYPE_DICTIONARY_DIR` paths; the latter is a legacy
resource-directory check and cannot override the embedded vocabulary. The
experimental IBus bridge can use `build/shared-engine/neptype-conformance` as its
explicit `NEPTYPE_IBUS_CORE_EXECUTABLE`. It requires no Swift runtime.

## Interfaces and verification

`shared/include/neptype_engine.h` defines ABI 2. Strings cross the ABI as UTF-8;
caret and mapping ranges use UTF-16. Modes are 0 mixed, 1 literal English and 2
All Nepali. A handle owns one document composer behind a mutex. Immutable results
own their strings until `neptype_result_destroy`. Never destroy a handle while
another call uses it. No engine call reads host editors, preferences or a network.

The JSON interface supports stateless rendering and compact input-session states.
Native document handles and the WebAssembly PadEngine retain undo history inside
Rust; Swift copies clone their document handle before mutation. It does not implement a remote service.
Swift structs preserve copy-on-write and undo behavior without reimplementing
ranking, tokenization, choice invalidation or session rules.

```sh
JDK_BIN=/path/to/jdk/bin bash scripts/verify-local.sh
```

Verification includes 2,286 frozen cases captured from the previous Swift core,
every one of the 2,449,776 packed external dictionary rows compared with its
source, Swift history/session tests, native C++/JNI/Python transport comparisons,
Rust input-preservation tests and actual WebAssembly rendering parity. The iOS
injected editor hosts exercise the built Rust-backed UI on a simulator.

The GitHub Actions matrix builds the native Rust core on macOS/Linux/Windows,
the Win32 frontend, both Android library ABIs/APK, Apple targets and the website.
Building and host simulation do not establish system keyboard behavior on every
OS. Real IBus/TSF hosts and device keyboard settings still require their existing
platform acceptance checks; this migration never enables or installs a keyboard.
