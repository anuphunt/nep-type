# NepType rebrand verification

Verified November 1, 2026 (America/Los_Angeles).

- `scripts/build.sh`: Mac NepType app built successfully.
- `scripts/build-input-source.sh`: NepType Input bundle built successfully; no input source was installed or enabled.
- `JDK_BIN=/opt/homebrew/opt/openjdk/bin bash scripts/verify-local.sh`: passed Swift tests, portable protocol and input preservation, malformed-index fallback, bundled-index shape, Linux mock IBus, Windows mock TSF, Android Java core and real-index tests, and iOS shared-source consistency.
- `xcodebuild -project platforms/ios/NepTypeMobile.xcodeproj -scheme NepTypeMobile -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/neptype-ios-brand-build CODE_SIGNING_ALLOWED=NO build`: succeeded.
- `build/NepType.app/Contents/MacOS/NepType --smoke-test evidence/neptype`: all 86 checks passed. The screenshot was inspected for the new name and header layout.
- `python3 -m unittest discover -s tools/fresh-build/tests -q`: all five build-guard tests passed.
- `bash platforms/ios/Tests/run-core.sh`: passed.
- `git diff --check`: passed.

The optional iOS container UI harness encountered a simulator pasteboard permission dialog before it could finish. It was stopped without granting access; this is not a completed UI test. Its earlier checked-in `last-results.json` is historical. The iOS simulator build and shared-core checks above passed. No Android SDK build, native Windows build, real Linux IBus session, or enabled system keyboard was tested during this rename.

Strict signature verification of the workspace Mac bundles encountered the existing file-provider FinderInfo issue documented in `tools/build-hygiene/README.md`. A targeted removal of that attribute from the newly generated bundles allowed the input bundle check to pass, while the app attribute recurred. The Mac app's executable and UI smoke test ran successfully. This was a local prototype build, not release signing or notarization validation.

The language TSV files were preserved. Remaining occurrences of the old letter sequence in the language fixtures are ordinary Roman transliterations, not app branding.

## Approved blue NT logo

The owner selected direction 1. A graphite app variant with a white N and blue T/cursor was created using the built-in imagegen tool. Its master and native icon exports are in `branding/assets`, with the exact final prompt in `branding/final-logo-prompt.txt`. The original three explorations are retained.

The logo is used by the Mac header and app/input bundle icons, iOS app icon and header, Android launcher icon and setup header, Linux header and source-preview assets, Windows executable/window/header icon, and landing-page previews. Both Mac build paths include the assets. The old iOS icon-generator entry point exports the approved artwork instead of drawing a placeholder.

After integration, both Mac bundles rebuilt successfully. The Mac UI smoke test passed all 86 checks, and `evidence/blue-nt/prototype.png` was inspected for the actual monogram and wordmark. The iOS simulator build succeeded with the new image set. All three Linux packaging tests and five isolated-build guard tests passed. The iOS app icon is 1024 × 1024 with no alpha channel. Native Android and Windows builds and real Linux rendering were not run for this visual change.
