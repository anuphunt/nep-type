# Windows typing-pad preview release

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

**Current release blocker:** automatic approval review rejected the initial
`git push -u origin codex/windows-installer` as an external commitment requiring
explicit user approval. The push did not execute; read-only `git ls-remote`
confirmed the branch was absent. Do not retry, push through another transport,
create a substitute remote branch, or publish until new trusted authorization
addresses this rejection. No Windows installer has been built or tested yet.

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
