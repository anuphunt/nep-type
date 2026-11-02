# Fresh local build experiment

`fresh-build.py` is a separate **development-only** build tool. It does not replace NepType's existing build scripts, install/enable an input source, publish, notarize, or select a signing identity. It uses the existing scripts' ad-hoc signing policy (`codesign --sign -`), which is not a trusted distribution signature. Aksharantar rights remain unresolved before distribution. The output is not a release-ready keyboard.

## What it does

- Requires an existing project and a **new output directory outside that project**. It refuses an existing destination rather than overwriting or merging it. The destination parent must be a real non-symlink directory; on macOS use `/private/tmp` instead of `/tmp` if `/tmp` is a symlink.
- Makes a unique temporary source snapshot of `Package.swift`, `Sources`, `Tests`, the two compiled indexes and their bundled attribution/manifests. It rejects symlinks in inputs and refuses files or parent directories carrying quarantine rather than stripping/bypassing it. Other source metadata is not copied into the generated snapshot. Input content hashes are checked before/after copying and against the snapshot.
- Reads the package manifest and refuses external package dependencies or target resources requiring further review. It uses `--disable-automatic-resolution`; the current manifest has no external dependencies. It does not intentionally use the network. This is not a network-isolation security boundary, and project source/toolchain must be trusted.
- Builds both executable products in release mode inside the snapshot, runs the Swift test suite, creates both app bundles from fresh empty directories, copies exactly the two local indexes and attribution, applies ad-hoc signing, and performs strict signature verification and plist checks. It creates the requested output only after those checks, then performs strict checks again on the final output. A filesystem can later add metadata and invalidate that check; verify at the point of use.
- Writes `build-inputs.json` with the input SHA-256 values, Swift/OS/architecture and build settings. This provides source traceability, not bit-for-bit reproducible executables: compiler, SDK, paths, signing metadata and filesystem can influence output. Source changes after the snapshot do not update an existing build.

If final copying or verification fails after the new destination is created, the script leaves that **new** directory in place and prints its path for inspection; it never automatically removes an existing destination. The experiment assumes a trusted local project/output parent and no hostile concurrent filesystem race. It is not hardened against an adversary replacing paths during the build. If project files change during copying, the build stops; a coordinated cross-file edit is not an atomic snapshot, so avoid editing the project while the snapshot is being created.

## Usage

```sh
python3 /path/to/fresh-build.py \
  --project /path/to/nepali-keyboard-prototype \
  --output /private/tmp/neptype-new-build
```

The `--output` path must not already exist. In this managed environment SwiftPM's nested sandbox could not start, and the release `dsymutil` phase was rejected by the outer sandbox. For local testing only, the explicitly authorized run used `--disable-swiftpm-sandbox` and elevated execution. Disabling SwiftPM's sandbox is a tradeoff, does not itself grant OS access, and should not be used with an untrusted project. The default retains SwiftPM's sandbox. No input-source registration or System Settings change is performed.

## Evidence and limits

On the development Apple Silicon Mac, two independent clean local runs using the same source snapshot completed, ran **29 Swift tests**, and passed immediate strict verification and plist lint for both bundles. Their 16 input hashes matched; the second run's manifest is in `sample-build-inputs.json`. Five guard tests passed for existing destination preservation, output inside the source project, symlinked inputs and quarantined file/parent refusal. Run them using:

```sh
PYTHONPYCACHEPREFIX=/tmp/neptype-fresh-pycache python3 -m unittest discover -s tests -v
```

The resulting bundles were not installed or activated. This work does not test IMK host behavior, Android/Windows/Linux builds, UI, accessibility, supported Intel builds, cold builds on other machines, crash durability, safe rollback, notarization or commercial rights. `--deep` signature verification checks the generated local artifact only and must not be interpreted as system trust. Before integrating this experimental builder into routine workflows, review its trust assumptions and test a clean machine and relevant architectures.
