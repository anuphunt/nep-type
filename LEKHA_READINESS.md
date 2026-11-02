# Lekha platform readiness — working assessment

This is an engineering status snapshot, not a release approval or a claim of ViKey parity. Update after any meaningful implementation or test change. Local test counts and evidence are in the platform READMEs and `LEKHA_PRODUCT_PLAN.md`; simulation and mock tests do not establish behavior in real apps.

| Surface | Current user-facing capability | Evidence | Main unresolved work |
|---|---|---|---|
| macOS typing pad | Native standalone pad, offline mixed/all-Nepali preview, candidate selection, original text and text-size control | Local app smoke test; `evidence/parity/ui-smoke-test.json` | Typing accuracy and accessibility need broader independent evaluation. This is a copy-and-paste pad, not system-wide input. |
| macOS input method | Built experimental IMK bundle, marked composition, candidate selection, session mode menu, in-memory and opt-in persisted per-app manual choices, and literal handling | Core tests, controller-level mode checks and IMK server construction; no host registration/typing test | Automatic approval review denied installation; action remains pending. No real-host focus/selection/secure fields, shortcut, undo or data-loss verification. |
| iOS | Experimental Swift-core candidate keyboard with original default and pre-commit restoration | Generic simulator extension build and temporary in-process UITextView host (97 checks), plus a separate container test (10 checks) | Actual enabled extension and third-party host not exercised; callback timing, secure contexts, accessibility, layout, memory, interrupt and text safety unverified. No safe post-commit rewrite. |
| Android | Experimental Java candidate keyboard with exact-index suggestions, opt-in approximate fallback, original default and preview | Local Java core/index tests only | Service/APK uncompiled: Android SDK, Gradle and adb unavailable. Real InputConnection, selection, accessibility, protected fields, performance and layout need device tests. No safe post-commit rewrite. |
| Linux | Experimental opt-in IBus adapter, async candidate worker, manual mode and keyboard selection | 47 Python mock IBus tests with locally built portable core | No actual Linux IBus daemon or native host tested. Linux Swift build, package/resource handling, focus, secure preedit and lifecycle unverified; pointer selection disabled. |
| Windows | TSF range/edit and key interaction experiments; production sink passes keys through | Mock COM/TSF tests and portable-core candidate probe on Mac | Windows SDK/host unavailable; no real DLL build, protected context handling, composition lifetime or live engine integration. No working Windows keyboard. |

## Quality evidence and interpretation

- Prior 59-word development fixture: Swift candidate list contained an accepted spelling for 45; Android's four index candidates contained one for 41. This is a previously used fixture, not an independent accuracy estimate.
- Prior synthetic mixed corpus: isolated options included accepted spellings for 41 of 43 Nepali tokens in each engine, and original text was offered for all 34 English tokens. These figures do not measure automatic decisions or real typing. See `evaluation/cross-platform/README.md` for exact setup and results.
- Dataset noise and uncertainty remain. Agree on representative independent Nepali-speaker-reviewed corpora, language/spelling metrics, latency limits and host-app compatibility gates before beta.
- Local input remains the intended default. No online decision API or AI model has been enabled. Aksharantar commercial licensing remains the user's unresolved task before distribution; attribution and provenance are in the data and platform projects.

## Before enabling or releasing

1. Complete safe range ownership, focus/selection, composition cancellation and secure-field handling for each platform; never rewrite unrelated committed text.
2. Run actual native host tests for typing, corrections, Unicode, keyboard layouts, app switching, crash/focus recovery, accessibility, install and removal on an agreed device/OS matrix.
3. Measure real-device startup, candidate latency, memory, disk use and battery; validate index packaging and fallback with missing/corrupt resources.
4. Resolve data and dependency redistribution terms; obtain signing and distribution approvals separately. No test here authorizes installation, publication or paid service use.

The latest code review uncovered text-ownership hazards. Current fail-closed transitions can leave a prior marked token unresolved or lost; see the platform READMEs and the product plan before use. A newly created 24-sentence synthetic diagnostic matched 11/24 proposed sentences before and after a conservative loanword rule; its references and both splits were inspected and are not an independent accuracy estimate.

The latest ownership guards remain conservative and are not proof of a host-owned range. A new inspected and unreviewed 30-sentence diagnostic matched 13/30 both before and after uncertainty labeling; see `evaluation/generalization/README.md`.

Actual iOS system-extension testing requires installing and enabling the keyboard in simulator Settings; no input source was enabled and this remains pending approval. Container and injected-controller simulator hosts do not prove extension behavior. Android setup and settings UI remain uncompiled.

`scripts/verify-local.sh` runs local core and mock checks only; it does not verify native input-source behavior. The proposed neighbor-ranking change in `evaluation/quality_probe/` was rejected and reverted because the diagnostic did not establish benefit and it could misconvert names.

A frozen, separately authored but synthetic/unreviewed 50-case probe found exact sentence matches English 10/10, Nepali 2/10, mixed 3/10, ambiguity 7/10 and literal 9/10; it is not a representative accuracy estimate. See `evaluation/frozen-probe/README.md`. Mac and Android per-app persistence is opt-in and local; Mac stores pseudonymous app-ID digests while Android stores package IDs. Real host behavior remains unverified.

Two later language experiments were evaluated on separately authored frozen synthetic probes and reverted: neither showed held-out benefit, and one introduced noisy alternatives. The probes are now spent, not future untouched holdouts. See `evaluation/frozen-comparison/README.md` and `evaluation/suggestion-probe/README.md`. Synthetic references remain unreviewed and nonrepresentative.

Mac pad candidate paging passed 46 automated checks after fixing a layout exception. The latest phonetic and morphology proposals were rejected on development evidence; no engine accuracy change was shipped. A synthetic 100-case reserved probe exists for a future frozen candidate, but is not a representative user sample. Linux now filters whitespace and oversized candidate responses, with real IBus still unverified.

An earlier standalone Mac pad version included an optional offline emoji picker and passed 75 automated smoke checks; the user later requested removal of the picker. Real VoiceOver and manual use are unverified. Android and Linux worker changes are tested locally but not in native hosts.

Release/privacy diagnostics are in `LEKHA_RELEASE_AUDIT.md`. Strict signature verification is unstable at the file-provider project path; clean temporary staging and extraction verified, but all preview signatures remain ad-hoc and not notarized.

Manual recovery controls on iOS and Android do not guarantee old marked text survives; they are user-invoked and remain unverified in actual keyboard hosts. See `evaluation/performance-study/README.md` for the small local indexed-memory/latency diagnostic and `tools/build-hygiene/README.md` for an optional staging experiment.

A structural index validation fix prevents obviously malformed or oversized rows from becoming candidates; full shipped-row shape scans passed. It is not an authenticity or linguistic-quality guarantee. An iOS packed-index research prototype reduced resource bytes but did not establish extension-memory savings; raw TSV remains in use. The emoji keyword study found gaps on a small unreviewed fixture. See the latest product-plan section and corresponding evaluation folders.

A separately authored frozen 55-case cross-platform probe did not justify the experimental Android phonetic fallback: it added four expected Nepali candidate occurrences but changed lists for 61/97 annotated English occurrences. The fallback was removed from general suggestions; a later explicitly selected All mode reintroduced it as an approximate option. Android remains original-by-default. The synthetic/unreviewed selective probe does not establish user outcomes or real accuracy. See `evaluation/platform-blind-results/README.md`. The optional fresh-build tool documents local traceability, not release reproducibility or system-host readiness.

Candidate bars received iOS selection accessibility and Android horizontal scrolling changes. The iOS system extension and Android service UI remain unverified. Windows mock edit isolation was strengthened, but its production sink still passes keys through. A small unreviewed synthetic development comparison did not justify a cross-platform ranking change; a separate synthetic probe remains unscored. See the latest product-plan entry.

The iOS prototype has a second symbols page, checked in its injected simulator host and a generic simulator build; actual extension and touch usability remain unverified.

iOS idle-row cursor controls have injected-host Unicode and stale-tap tests; real proxy offsets, truncated context and host behavior remain unverified.

The current standalone Mac pad has a single sidebar settings window, remembered mixed/all-Nepali modes, Nepali sentence-ending punctuation, and mapped output-word selection. The separate settings panel and emoji picker are no longer present. A refresh optimization and 79 local UI checks passed; the mapped-word hover and click are still not validated through real pointer interaction or VoiceOver. See the latest product-plan entry.

All Nepali is exposed in the uninstalled Mac input-method menu, in the iOS experimental suggestion row, and in the Linux IBus language property. iOS and Linux retain Roman text by default and require selecting a candidate; Mac controller behavior is covered locally. Real enabled keyboard hosts remain unverified on all three. Android has a separate opt-in approximation control described below; Windows does not expose this mode.

Android source now has an opt-in, session-only All suggestions control that can expose an explicitly labeled approximate phonetic fallback when indexes have no result. Original text remains the default and Use is required. Its quality is unvalidated and the Android service is still uncompiled and untested on a device. Windows still has no live TSF conversion or All mode.
