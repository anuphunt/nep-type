# Mac desktop release

## Published 0.1.2 (build 3)

This release simplifies the Mac keyboard setup into four separately spaced bullets, uses readable dark appearance, and replaces the wide More dropdown with a compact bottom-right button opening a feedback dialog. It includes the existing optional experimental input source; engine and keyboard behavior are unchanged.

Built from Mac-only source `4fe1bcdc89a6c4b430f6536e1aae2b1c2f1988fc` on current main, preserving concurrent Windows and website changes. Universal arm64/x86_64 executables target macOS 13. App, independently installable input source and DMG are Developer ID signed, notarized and stapled.

DMG: `91,569,843` bytes; SHA-256 `4ed1032641839d2eea479ba3bb559364a2778dfaaf04f5475357d310029b3ff0`. Accepted submissions: input source `7dde556a-517c-424d-a882-31dc35834894`, app `6f2b5828-494a-4f82-81f7-ebd0f1da7f3e`, DMG `238f2e67-361e-46ca-85a7-87f8ca52bb9d`. Final-copy UI/shortcut and installer verification is recorded with the artifact evidence.

[Release](https://github.com/anuphunt/nep-type/releases/tag/mac-v0.1.2), [merged source PR](https://github.com/anuphunt/nep-type/pull/3), and [passing exact-source CI](https://github.com/anuphunt/nep-type/actions/runs/41949001708). The published installer and checksum were re-downloaded and match the byte count and SHA-256 above. Final DMG-copy checks passed signatures, Gatekeeper, stapled tickets, 123 UI checks, 22 AppKit shortcut checks, input-server/mode guards and temporary-folder installation/overwrite rejection. The website manifest points to this immutable verified asset. Prior 0.1.1 assets remain available. Intel hardware and real-host input-source compatibility remain unverified; the keyboard remains experimental. No TestFlight or Windows installer operation is included.

## Published 0.1.1 (build 2)

[Mac release](https://github.com/anuphunt/nep-type/releases/tag/mac-v0.1.1), built from `1c783150a041f4054bda55dff0ebff543195a2ec`. Universal arm64/x86_64 executables target macOS 13. App, bundled experimental input source and DMG are Developer ID signed, notarized and stapled. Their accepted notarization submissions are recorded in the release assets.

DMG: `91,562,540` bytes; SHA-256 `46f83af9c42d231b826f316f63f7d8f4d6d3a00408b55c099b822ef3775d8e6f`.

[Full source CI](https://github.com/anuphunt/nep-type/actions/runs/41712512893) passed. The final read-only DMG copy passes Gatekeeper/signature/ticket validation, 108 UI checks (including 22 shortcut cases), the standalone 22-case AppKit suite, input-source self-checks and private-folder installer tests. The installed user app and input sources were not replaced or enabled. Intel hardware and host-app compatibility for the experimental input source remain unverified.

## Release procedure

Build from a clean, committed integration checkout. Use a new numeric version and build number; retain previous public release assets. Set the existing `NEPTYPE_MAC_SIGNING_IDENTITY` and `NEPTYPE_MAC_NOTARY_PROFILE` without committing credentials, then run `bash scripts/package-mac.sh`. It builds universal Apple silicon/Intel pad and input-source binaries targeting macOS 13, signs nested code before the containing app with hardened runtime, notarizes/staples the independently installable input source, app and DMG, and records source revision, SHA-256 and submission evidence under `build/releases/mac-VERSION`.

Run Swift/Rust/transport, UI/shortcut and input-method self-checks on final integrated sources. Mount the final DMG read-only, copy the app into a disposable Applications folder, verify both architecture slices, signatures, tickets and dictionary identity, and rerun smoke/shortcut tests from that copy. Test `InputMethodInstaller` only into a fresh temporary directory; do not overwrite or activate the user's installed apps or input sources. Automated input-method checks do not establish host-app compatibility. Label the optional input source experimental until real-host acceptance is available.

Publish only successful, verified artifacts under a new immutable GitHub release tag at the tested source commit. Update website manifest/checksum/source revision after publication and verify live pages and streamed download hashes. Never replace old-version assets with different bytes. Keep signing material, local build paths and credentials out of Git.
