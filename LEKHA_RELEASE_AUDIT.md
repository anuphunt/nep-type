# Lekha local build and privacy audit

This is a development audit, not a release approval. No input source was installed, enabled, published or notarized during this work.

## Mac preview signatures

The saved parity preview bundles are ad-hoc signed and arm64-only, with no Apple team identity; they are not Developer ID signed or notarized. Ordinary `codesign --verify --deep` passed, but strict verification at the project path failed on top-level `com.apple.FinderInfo`. Removing that specific attribute temporarily made strict verification pass, but it returned in this file-provider-backed location. Do not treat project-path strict signature validity as durable. Existing build scripts also reuse predictable scratch directories and merge into existing build outputs; production packaging should use clean unique staging and verify the final artifact. Never clear quarantine or unrelated attributes as a workaround.

A clean `ditto --noextattr --norsrc` temporary staging copy of the Mac pad passed `codesign --verify --deep --strict`. A local development ZIP was created from that clean staging copy and a fresh temporary extraction also passed strict verification. Its SHA-256 is `d6f8882683fd05662ad6f84a48fd8c45faea67d6d54834bf8bf27031255b8039`. This does not make it signed for distribution; the ZIP contains the user-authorized datasets whose redistribution review remains unresolved. It was not published. Recheck the checksum and signature after transfer or extraction; filesystem metadata can recur.

## Mobile and resources

The generic unsigned iOS Simulator app and extension have matching development versions 0.1.0 (1) after this update. This is not a signed or device-tested release. Android remains uncompiled without SDK/Gradle. Both Mac preview bundles are about 106 MiB, and iOS/Android index resource directories are about 104 MiB each; actual device startup and memory are unmeasured. Local audit found Google and Aksharantar index hashes match across project data, Mac previews, and mobile resource directories. The Aksharantar manifest records unresolved source/redistribution rights; the user will handle commercial licensing before distribution.

## Privacy and security observations

Android's manifest declares no INTERNET permission and disables backup; the iOS extension declares `RequestsOpenAccess=false`. These are static configuration facts, not proof of runtime privacy. Linux's candidate subprocess receives only explicitly selected locale and local-index environment variables, not unrelated inherited credentials; it still receives typed tokens and the configured executable must be trusted. Per-app language preferences are opt-in and local where implemented; Mac hashes identifiers without claiming anonymity, while Android stores package identifiers/modes. Review real-host secure fields, logs, crash handling, permissions, update/network policy and data deletion before release.

The iOS keyboard now pauses when an external callback makes composition ownership uncertain. This avoids an unverified write but can interrupt ordinary typing and leave a prior mark unresolved; actual extension callback ordering remains unverified. Android and Linux similarly use conservative fail-closed paths with documented loss/host risks. Windows production TSF sink still passes keys through and has not been compiled on Windows. See platform READMEs and `LEKHA_READINESS.md`.

A later local-only development staging experiment is in `tools/build-hygiene/`. It refuses to overwrite, refuses quarantined or symlink-containing sources, does not sign/install/enable, and performs immediate strict signature verification on a newly created copy. It preserves the source and does not replace existing build scripts. Metadata can recur after verification; an ad-hoc valid signature does not establish notarization, trust or release rights. Its tests do not establish resistance to concurrent hostile filesystem changes.

A later Mac preview with keyboard emoji navigation was staged and smoke-tested locally. `build/Lekha Keyboard Local Preview.zip` has SHA-256 `ab9778d0ad173a1c30cc8e24ccf1ef6b072769ad9e4ae448360e39d388c0b0ed`; a temporary extraction passed strict signature verification immediately. It remains an ad-hoc-signed, arm64-only development artifact, with dataset rights unresolved before distribution.

The later Mac visual and index-validation preview is `build/Lekha Visual Local Preview.zip`, SHA-256 `a01aac4b56ef741957b781fb15d3af30740d79bf723e12272a3c03b2925878ed`. A temporary extraction passed strict verification immediately. It remains ad-hoc signed, arm64-only and not notarized; file-provider metadata and data-rights caveats above still apply.
