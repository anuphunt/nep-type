# Windows typing-pad preview release

## Version 0.1.1-preview.1 release

The new release integrates Ctrl+1–3 selection, request/selection staleness guards, local draft and mode saving, automatic spelling memory, desktop tools and truthful keyboard-setup guidance. The experimental TSF service remains excluded. Prior releases and their verification records below remain recoverable; new binaries require new versioned assets.

[Published release](https://github.com/anuphunt/nep-type/releases/tag/windows-v0.1.1-preview.1), source `1c783150a041f4054bda55dff0ebff543195a2ec`. Installer: `18,452,849` bytes; SHA-256 `a71156a812109bdb0499bdc33f66e24354150c12ad642c8d89764be1856277c9`.

[Exact-source Windows CI](https://github.com/anuphunt/nep-type/actions/runs/41712600387) passed native SDK/Rich Edit tests and 61 installed-app checks, including first-launch setup guidance, offline render/copy, gaadi/gadi/gayera corrections, local draft/mode restoration, reinstall and uninstall. Verification ran on Windows Server 2022; consumer Windows 10/11, ARM64, high-DPI/accessibility and browser/SmartScreen acceptance remain unverified. The installer remains unsigned. Evidence and installed-app screenshots are release assets.

The Mac release is separately signed and notarized at version 0.1.1. The desktop integration does not change iOS source or TestFlight distribution.

## Previous published release record

## Scope and current state

This release is the native Win32 **typing pad**, backed by the same offline Rust
engine as the website. Users write in NepType and copy/paste into another app.
The unfinished TSF service is not included, registered or enabled. Do not describe
this package as a system-wide keyboard.

Version: `0.1.0-preview.1`; Windows 10/11 x64 (Intel/AMD) target. ARM64 is untested.
No Windows signing certificate has been configured. The package is intentionally
labelled unsigned; browser and SmartScreen warnings are possible. Do not claim a
verified publisher, established SmartScreen reputation or warning-free install.

Preparation is isolated from the unfinished primary checkout. Base source:
`964a4bb27d1d355e99f62726890992c90a94bd60` (includes the published Mac DMG).
Local branch: `codex/windows-installer`.

The user explicitly approved the installer-branch push and unsigned publication
conditional on passing Windows checks. All Windows gates passed at
https://github.com/anuphunt/nep-type/actions/runs/41527376340 on tested source
`2d4eb1be5f5f7cf0d8529266df7d3e242e9ba14b`.

Version `0.1.0-preview.1` is published as a GitHub prerelease at
https://github.com/anuphunt/nep-type/releases/tag/windows-v0.1.0-preview.1.
The public installer was downloaded without GitHub authentication and its SHA-256
and byte count match the passing CI artifact: 18,402,724 bytes,
`738ddb170a0db676f2f4f3a2f61c9d43eb32c12aed5e2ab87b3e85205b88cd68`.
Authenticode reports `NotSigned`.

The first run failed because its fixture expected `pani` to default to `पानी`.
The independent native contract and captured Windows controls confirm default
`पनि`, alternatives `पनि`, `पानी`, `pani`, then a genuine output change to `पानी`
after selection and recovery of original `pani`. Only verification and diagnostics
changed; engine and shortcut behavior did not. The passing run also completed
mixed/All Nepali modes, clear, clean exit, same-version reinstall, relaunch and
complete removal. Its installed-window screenshot was inspected. The failed
artifact remains unverified and must not be distributed as this release.

## Packaging

`.github/workflows/windows-installer.yml` uses the existing GitHub Windows runner
and its installed Inno Setup 6. It does not install paid tools or obtain signing
credentials. It has read-only repository permissions and no automatic release or
website deployment step. It triggers on the dedicated branch, relevant pull
requests, or manual dispatch once the workflow exists on the default branch.

The workflow checks the pinned dictionary, runs Rust tests, ABI/conformance and
input-preservation checks, builds the Win32 app and dormant TSF compile target,
and runs CTest with assertions retained in Release. Rust uses the explicit
`x86_64-pc-windows-msvc` target with static CRT; CMake uses `/MT` for Release.

`installer/package.ps1` stages an explicit file allowlist, then compiles
`installer/neptype.iss`. The payload contains `NepType.exe`, `NepTypeEngine.dll`,
licenses, a plain-text preview guide and staged dictionary identity/attribution.
Inno installs under the user's LocalAppData Programs directory without requesting
administrator access, makes a user Start shortcut and provides Windows uninstall
registration. It does not auto-launch silently or install a desktop shortcut.

## Required Windows CI evidence

`installer/verify.ps1` must succeed. It installs to a fresh path containing spaces
and Devanagari, checks installer SHA-256 and unsigned status, compares installed
bytes with the payload, verifies no TSF artifact is present, inspects native
dependencies for an unwanted Visual C++ redistributable requirement, then launches
from an unrelated working directory without engine-path overrides. Native
controls exercise Roman-to-Nepali output, Unicode clipboard copy, alternate
spelling selection, mixed and All Nepali modes, clear and clean exit. It also
checks same-version reinstall, relaunch, removal of files, Start shortcut and
per-user uninstall entry. The artifact includes logs, a window screenshot,
package metadata and `verification.json`; failure artifacts are retained too.

Only a successful workflow with `package.tested: true` and
`verification.success: true` qualifies. A retained artifact from a failed run does
not qualify. Inspect `installed-pad.png` for Devanagari rendering/layout before
publishing. The runner is Windows **Server 2022 with development tools**, not a
clean consumer Windows 10/11 computer. Automated Win32 control messages do not
prove physical keyboard interaction, accessibility, high DPI, browser download,
SmartScreen behaviour, antivirus acceptance or ARM64. Those require additional
real-device/manual checks. State these limits in release notes and on the website.

## Publish after authorization and successful verification

1. Fetch remote main; retain concurrent Mac/website releases. Rebase the isolated
   branch as needed; never overwrite the primary checkout or force-push main.
2. Push the reviewed branch after explicit approval. Run/inspect Windows CI. Fix
   failures without weakening checks and re-run on the exact release commit.
3. Download the successful `neptype-windows-x64` artifact. Verify its source SHA,
   complete successful check report, screenshot, executable and checksum. Verify
   the installer bytes with SHA-256. Keep binaries out of Git.
4. Create immutable GitHub **prerelease** tag
   `windows-v0.1.0-preview.1` at the tested source commit. Upload the `.exe`, its
   `.exe.sha256`, package and verification metadata. Release title must say
   unsigned typing-pad preview. Include the limitations above and distinguish
   automated Server verification from consumer Windows testing.
5. Download the published installer and checksum again and compare SHA-256 and
   byte count with the verified artifact. Do not replace assets under an existing
   version; use a new preview version for changed binary bytes.
6. Fill `landing-page/windows-release.json` from that evidence: `verified: true`,
   exact immutable release URL, SHA-256, bytes, tested source commit and successful
   Actions run URL; retain `signing: unsigned` and `systemKeyboard: false`.
   `windows-release.mjs` rejects incomplete or inconsistent release metadata.
7. Run website tests, a production build and desktop/mobile browser review in both
   languages. Verify installer/checksum links, metadata, nav, no-JavaScript content
   and the existing Mac download. Merge only the scoped, verified changes through
   the normal repository deployment path. Recheck latest remote state first.
8. Check Netlify production readiness and live `/windows/`, `/ne/windows/`, both
   homepages, sitemap and the actual release downloads. Record deployed commit,
   release URL/hash, CI run and remaining test limits.

Until these gates pass, `windows-release.json` stays `verified: false`, and the
website build emits no Windows installer link or download structured data.
