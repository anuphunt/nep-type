# Local bundle staging experiment

`stage-preview.sh` copies an **already built and signed** `.app` to a new destination, checks its existing signature, and runs strict verification on the copy. It never signs, installs, enables, publishes or notarizes an app. It is an experimental development aid, not a release workflow or a substitute for a trusted identity, notarization, license review, clean-machine testing or final-artifact verification.

The current NepType scripts build in predictable reused scratch directories and `ditto` into existing build paths, allowing stale contents. They also save onto a file-provider-backed directory where FinderInfo can recur and break strict verification. This staging tool makes a new empty destination using `mkdir` and refuses overwrite or an output inside the source. It uses `cp -a` for the copy, then removes **only** top-level `com.apple.FinderInfo` from the newly created copy if present, leaving the source unchanged. It refuses quarantined sources instead of attempting to remove or work around quarantine, and refuses symlink-containing bundles. It does not erase arbitrary xattrs. macOS may normalize metadata during copying, and this does not guarantee complete xattr identity. Strict validity is checked immediately and can become invalid later if filesystem metadata is added; verify again at the point of use. No trust or release status is implied by an ad-hoc signature.

Usage from a trusted local project build, specifying a new destination whose parent already exists:

```sh
./stage-preview.sh '/path/to/NepType.app' '/tmp/NepType Local Stage.app'
codesign --verify --deep --strict --verbose=2 '/tmp/NepType Local Stage.app'
```

If copying or verification fails after destination creation, the tool leaves the new incomplete copy in place and says where it is. Inspect it before deleting; it never overwrites existing data. It rejects sources containing symlinks or quarantine, and refuses if it cannot inspect the source. It assumes the source is a trusted, non-concurrently-changing local bundle, and does not harden against hostile filesystem races. It does not check source provenance, nested bundles' distribution terms, architecture coverage, memory, dynamic loading, privacy or application behavior.

## Local verification

On this Mac, `./tests.sh '/path/to/an/existing/signed-dev.app'` passed: strict verification immediately after staging, unrelated custom root attribute retained in this test, existing output refused, output within source refused, top-level and nested symlink sources refused, top-level and nested quarantined sources refused, and original test-copy attributes retained. The test creates a unique temporary directory and cleans only that directory; it does not alter the supplied source or sign software. `bash -n` passed for both scripts. The test source was the existing ad-hoc-signed NepType preview. No Windows/Android/iOS release build was tested or changed.

This is a separate experiment and has **not** replaced `scripts/build.sh` or `scripts/build-input-source.sh`. For actual release, establish a clean unique build pipeline, safe rollback, supported architecture matrix, matching versions, verified data rights, developer signing/notarization and distribution approval. The source-only Linux preview archive and unsigned iOS/Android prototype builds have separate status in the main product plan.
