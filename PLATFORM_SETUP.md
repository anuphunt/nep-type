# NepType developer setup and current platform status

This guide is for the current **experimental local project**, not a release or a claim that system keyboards work. Project root on this Mac:

```sh
cd /Users/anupdhakal/Desktop/apps/nepali-keyboard-prototype
```

Keep existing input sources available. No step below enables or installs a keyboard. The earlier Mac input-source installation was denied by automatic approval review; activation remains pending approval. Installing/enabling the iOS extension in Simulator Settings also needs the pending authorization. Do not bypass a denial or system prompt. Test with disposable text, not sensitive or valuable documents: marked text can be lost or remain unresolved when a host changes focus.

## Start with the Mac typing pad

Open the **standalone copy-and-paste pad**, not the input-method bundle:

```sh
open 'build/NepType Parity Preview.app'
```

Type Roman text in the top box; select a word to inspect alternatives, keep the Roman original if desired, and copy the result. The pad has its own language and text-size settings, candidate paging and offline emoji picker; those controls do **not** configure the system input method. The app is an ad-hoc-signed local preview, not notarized. The file-provider-backed project folder can reintroduce Finder metadata and make strict signature verification fail even when an immediately verified temporary staged copy passes. See `NEPTYPE_RELEASE_AUDIT.md`; do not clear quarantine to work around this.

To rebuild the pad locally with an already installed Xcode/Swift toolchain:

```sh
bash scripts/build.sh --disable-sandbox
open 'build/NepType.app'
```

An optional fresh local build experiment is documented in `tools/fresh-build/README.md`; it writes only to a new output outside the project, runs tests and records source hashes. It uses the same ad-hoc development signing policy and is not a release builder.

The build writes its generated app and reuses a temporary scratch directory. Its existing `ditto` step can merge into a previous generated output; use a clean unique build/staging process for release work. `--disable-sandbox` avoids nested SwiftPM sandboxing in this managed environment; it is not an instruction to disable macOS security. `tools/build-hygiene/README.md` describes an optional local-only, non-overwriting staging diagnostic. The current scripts do not perform Developer ID signing, notarization or distribution.

## Run local checks on this Mac

With the existing Homebrew JDK (or another compatible installed JDK), run from the root:

```sh
JDK_BIN=/opt/homebrew/opt/openjdk/bin ./scripts/verify-local.sh
```

The script uses local temporary build/cache locations and runs Swift core tests, portable harness and malformed-index checks, index-shape checks, Linux mock IBus tests, Windows mock TSF tests, Android pure-Java tests when `JDK_BIN` is supplied, and iOS core-snapshot consistency. It uses no input-source registration or settings change. It does **not** build the Android service or Windows DLL, exercise real IBus or system keyboards, or establish privacy, data-loss safety, device performance or accessibility. An Android skip is reported if no JDK path is supplied. See the platform READMEs for the individual commands and requirements.

## macOS input-method prototype

The product owner has tested the separate Mac InputMethodKit keyboard and confirmed it works (2026-11-04). To build only, without installing or activating it:

```sh
bash scripts/build-input-source.sh --disable-sandbox
'build/NepType Input.app/Contents/MacOS/NepTypeInput' --server-check
'build/NepType Input.app/Contents/MacOS/NepTypeInput' --mode-menu-check
```

Server construction and synthetic menu checks do not prove that macOS registered the source, routes menu/keys correctly, or preserves host text, focus, selections, secure fields or undo. The guide in `docs/PHASE4_INPUT_METHOD.md` records the prospective installation and removal flow; those external settings/files remain subject to the pending approval and must not be performed by this guide alone. Client-proxy ownership is conservative and an unfinished mark may remain unresolved or be lost.

## iOS

The project `platforms/ios/NepTypeMobile.xcodeproj` contains a container app and an experimental keyboard extension. Check that its copied source and indexes match the root, then perform an **unsigned generic Simulator build**:

```sh
cd platforms/ios
./sync-core.sh --check
xcodebuild -project NepTypeMobile.xcodeproj -scheme NepTypeMobile -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/neptype-ios-development CODE_SIGNING_ALLOWED=NO build
```

A mismatch means the snapshot must be deliberately synchronized and retested; see `platforms/ios/README.md`. The project uses local raw TSV indexes, requests no Full Access, and the simulator build does not enable a keyboard. `Tests/run-core.sh` runs a Mac-process snapshot check. The separate `Tests/SimulatorHost/run.sh BOOTED_SIMULATOR_UDID` and `NepTypeMobile/Tests/run.sh BOOTED_SIMULATOR_UDID` create and remove temporary **standalone simulator test apps**, not keyboard extensions, and refuse to replace an existing test ID. Run them only in an authorized simulator environment; they do not establish actual system-extension behavior. Actual extension-host testing requires adding/enabling the keyboard in simulator settings and remains pending approval. On uncertain ownership the prototype may pause and leave an old mark unresolved or lost; do not use it for real typing.

The compressed-index work in `evaluation/ios-index-study` is research only. It was not integrated; the shipping prototype still bundles the raw indexes. Simulator memory measurements did not establish a reliable extension-memory reduction.

## Android

`platforms/android` contains an experimental `InputMethodService`, setup UI and offline indexes. It defaults to original Roman text until the user selects a candidate, with explicit English/Nepali mode; behavior is not equivalent to the Swift context ranker. On this Mac, only its platform-independent Java code can be tested:

```sh
cd platforms/android
JDK_BIN=/opt/homebrew/opt/openjdk/bin ./tests/run-core.sh
```

A JDK is present, but Android SDK, Gradle and adb were not found in checked locations. The project names Android Gradle Plugin 8.9.3 and SDK 35; their compatibility, the service, APK, settings UI, field ownership, lifecycle, TalkBack and performance are **unverified**. Provisioning build tools, installing an APK or enabling an input method is a separate authorized operation; none is performed here. The optional persisted app-mode preference is off by default and stores package identifiers and modes locally, not typed text; package identifiers are still sensitive metadata. Recovery/clipboard and fail-closed behavior are described in the Android README and remain untested on-device.

## Linux

`platforms/linux` is an IBus experiment; it defaults to pass-through. On this Mac, use the root verification script for mocked-host tests and run the read-only environment diagnostic:

```sh
cd platforms/linux
python3 diagnose.py
python3 generate_descriptor.py
```

The diagnostic does not connect to IBus, and descriptor generation prints XML without installing it. A future real Linux test requires an approved Linux environment with IBus/PyGObject and a portable-core executable built for **that target**; a Mac binary is not a Linux executable. Explicit core and index paths, optional focus experiments, setup and remaining risks are documented in `platforms/linux/README.md`. No IBus daemon, Linux VM/container or real host was available here. Input context/focus, preedit, protected fields, undo, lifecycle and recovery remain unverified; old preedit can be lost.

## Windows

`platforms/windows` contains the Win32 pad, live TSF keyboard, registration and explicit installer. The local script runs portable policy and mock host tests:

```sh
cd platforms/windows
./tests/run.sh
```

The production keyboard target now connects TSF key events to the shared offline engine and owned composition ranges. Windows CTest includes the production DLL in a real Microsoft TSF test context. OS routing, installation and real application acceptance must be verified on Windows; see [the Windows README](platforms/windows/README.md) and [acceptance checklist](docs/WINDOWS_KEYBOARD_ACCEPTANCE.md).

## Data and release gates

The indexes are local project resources. The user has chosen to use Aksharantar during development and will address its commercial licensing before distribution; source-chain and redistribution rights remain unresolved. Preserve notices in `data/sources` and the manifest. Google-derived data and code dependencies have their own attribution/license requirements. Before an external release, review all rights, signing and notarization, privacy and update behavior, accessibility, memory/latency on devices, failure recovery, actual host matrices, installation/removal and support. Distribution, publication and paid services require separate approval. `NEPTYPE_READINESS.md` and `NEPTYPE_PRODUCT_PLAN.md` are the current detailed status and roadmap.
