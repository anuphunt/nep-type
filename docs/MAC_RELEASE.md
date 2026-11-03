# Mac desktop release

## Published 0.1.1 (build 2)

[Mac release](https://github.com/anuphunt/nep-type/releases/tag/mac-v0.1.1), built from `1c783150a041f4054bda55dff0ebff543195a2ec`. Universal arm64/x86_64 executables target macOS 13. App, bundled experimental input source and DMG are Developer ID signed, notarized and stapled. Their accepted notarization submissions are recorded in the release assets.

DMG: `91,562,540` bytes; SHA-256 `46f83af9c42d231b826f316f63f7d8f4d6d3a00408b55c099b822ef3775d8e6f`.

[Full source CI](https://github.com/anuphunt/nep-type/actions/runs/41712512893) passed. The final read-only DMG copy passes Gatekeeper/signature/ticket validation, 108 UI checks (including 22 shortcut cases), the standalone 22-case AppKit suite, input-source self-checks and private-folder installer tests. The installed user app and input sources were not replaced or enabled. Intel hardware and host-app compatibility for the experimental input source remain unverified.

## Release procedure

Build from a clean, committed integration checkout. Use a new numeric version and build number; retain previous public release assets. Set the existing `NEPTYPE_MAC_SIGNING_IDENTITY` and `NEPTYPE_MAC_NOTARY_PROFILE` without committing credentials, then run `bash scripts/package-mac.sh`. It builds universal Apple silicon/Intel pad and input-source binaries targeting macOS 13, signs nested code before the containing app with hardened runtime, notarizes/staples the independently installable input source, app and DMG, and records source revision, SHA-256 and submission evidence under `build/releases/mac-VERSION`.

Run Swift/Rust/transport, UI/shortcut and input-method self-checks on final integrated sources. Mount the final DMG read-only, copy the app into a disposable Applications folder, verify both architecture slices, signatures, tickets and dictionary identity, and rerun smoke/shortcut tests from that copy. Test `InputMethodInstaller` only into a fresh temporary directory; do not overwrite or activate the user's installed apps or input sources. Automated input-method checks do not establish host-app compatibility. Label the optional input source experimental until real-host acceptance is available.

Publish only successful, verified artifacts under a new immutable GitHub release tag at the tested source commit. Update website manifest/checksum/source revision after publication and verify live pages and streamed download hashes. Never replace old-version assets with different bytes. Keep signing material, local build paths and credentials out of Git.
