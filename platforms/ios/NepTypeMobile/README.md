# iPhone Graphite typing pad

The container app uses the Mac app's Graphite palette. Roman input and selectable Nepali output are centered in the available space, with a maximum panel width of 360 points. The suggestion strip sits immediately above the software keyboard through UIKit's keyboard layout guide, and moves to the bottom safe area when the keyboard closes. Short screens and larger documents can scroll. Clear and copy have aligned 44-point touch targets; copy becomes a checkmark after copying. The pad uses the existing shared offline Swift engine, preserves the Roman source, supports Nepali + EN and All Nepali, and rejects stale suggestion actions after edits. Rendering runs on a serial background queue. No keyboard extension needs to be enabled to use the pad.

The help button retains keyboard setup instructions, the explicit Open NepType settings action, privacy information, and text-size settings. The size slider changes the two pad fields only. Keyboard setup still requires a user action in iOS Settings; the app never enables it automatically. The custom keyboard has the same Graphite colors, while its existing composition and host-ownership behavior remain unchanged.

The keyboard setup guide opens automatically the first time the updated app is
shown. An **Add NepType to your iPhone keyboard** link below the main toolbar
and its adjacent **ⓘ** button reopen it anytime. The banner wraps on narrow screens.
The **?** button opens general typing help and settings, including text size,
spelling memory, privacy, analytics preferences and feedback.
The guide shows three steps: Settings → General → Keyboard →
Keyboards; Add New Keyboard → NepType; then hold the globe key in a text field
and choose NepType. It explains that Full Access is not needed. **Done** dismisses
the guide, and a local preference prevents it opening automatically again. This
preference records presentation only; it does not claim the keyboard was enabled.

**Open Settings** uses Apple's public `UIApplication.openSettingsURLString` to
open NepType's app settings. The guide includes the full manual path in case
there is no Keyboards option on that page. It does not use private Settings URLs
or change any keyboard settings automatically. Both the scrollable guide and its
persistent settings button support small screens and landscape. The simulator
harness checks first presentation, persistence across controller recreation,
dismissal, reopening, step copy, layout, and explicit settings-button dispatch;
it never opens Settings or enables the keyboard. The guide preview is saved to
`evidence/platforms/iphone-keyboard-setup.png` at the repository root.

The main app target compiles `Composer.swift` from the primary core and the same transliterator/index sources used by the extension. Each target bundles its own index resources; this increases the development bundle size. Shared resource packaging can be addressed separately before a release.

The device target includes a single 1024-point Graphite app icon in an asset catalog, a matching launch background, supported iPhone/iPad orientations, and the offline app's encryption declaration. Regenerate the icon with `swift platforms/ios/generate-app-icon.swift` from the repository root. The icon follows [Apple's asset catalog workflow](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

For a signed device archive, use `xcodebuild -project platforms/ios/NepTypeMobile.xcodeproj -scheme NepTypeMobile -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/NepTypeMobile.xcarchive DEVELOPMENT_TEAM=YOUR_TEAM_ID CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates archive`. Export locally with `xcodebuild -exportArchive -archivePath /tmp/NepTypeMobile.xcarchive -exportPath /tmp/NepTypeMobile-export -exportOptionsPlist platforms/ios/ExportOptions.plist -allowProvisioningUpdates`. This creates an App Store distribution IPA; it becomes installable on a tester's iPhone through TestFlight after upload, Apple processing, and tester access. A local IPA link does not provide TestFlight installation.

`Tests/run.sh BOOTED_SIMULATOR_UDID` creates, runs, and removes a temporary standalone simulator app with no extension. Its checks cover actual conversion, original preservation, suggestions, stale actions, both output modes, copy feedback, empty-state copying, text size, help, and layout at small, standard, large, and landscape sizes with simulated bottom insets. It also opens the system software keyboard and checks the live suggestion edge and panel centering. It saves results in `Tests/last-results.json`, a rendered view in `evidence/platforms/iphone.png`, and the full simulator display with keyboard in `evidence/platforms/iphone-keyboard.png`. It does not enable the custom keyboard or open system settings. The keyboard's separate host harness remains available under `../Tests/SimulatorHost`.

## iPhone usage analytics

The [NepType iPhone app dashboard](https://us.posthog.com/project/329288/dashboard/2290734)
uses the existing website project in Anup's Org (project 329288, UTC timezone).
It contains companion-app and typing-pad DAU, rolling WAU/MAU, first observed app
users, an open → edit → copy activation funnel, D1/D7/D30 pad retention, edited
output copies, mode selections, and suggestion/original selections. These are
application-specific definitions; the connection cannot access the governed Data Catalog.

**Scope:** app DAU counts anonymous installations opening the companion app;
pad DAU counts installations editing its input. Neither measures the custom
keyboard inside other apps. That extension still has `RequestsOpenAccess=false`,
no analytics code, no network access and no shared-container writes. Opening
Settings is setup intent, not proof that the keyboard was enabled or used.
A reinstall/cleared app data can create a new installation ID. Opted-out and
offline users can be missing or delayed; these are not exact people or install counts.

### Build configuration

The app target alone links the official PostHog iOS SDK, pinned in
`project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Copy
`../Analytics.local.xcconfig.example` to `../Analytics.local.xcconfig`, then set
the **public project token** and ingestion host from project settings. This local
file is gitignored; it is configured on this machine for the existing website
project. Xcconfig URLs require `https:/$()/us.i.posthog.com` so `//` is not parsed
as a comment. CI may supply `NEPTYPE_POSTHOG_KEY` and `NEPTYPE_POSTHOG_HOST` as
Xcode build settings instead. Both values are embedded in the main app's plist.
Missing/invalid configuration disables analytics without affecting typing.
Never use a personal PostHog API key. Configuration is not included in the extension.

Debug builds and every simulator build send `is_test=true`; every saved dashboard
chart requires `is_test=false`. Release device builds, including TestFlight,
count as real app usage. No TestFlight build was uploaded for this change.

### Event contract

All events start with `neptype_ios_`. Fixed metadata includes `app=neptype`,
`platform=ios`, `surface=companion_app`, `schema_version=1`, app version/build,
and `is_test`. There is a random persistent SDK installation identifier, with no
login, advertising identifier, cross-platform identity merge or person profiles.

| Event suffix | Trigger / fixed extra fields |
| --- | --- |
| `app_opened` | Foreground activation; also records activity when a user action crosses a UTC day boundary |
| `pad_used` | First nonempty user edit per foreground visit/UTC day; `mode` |
| `output_copied` | Successful copy; `mode`, `content_origin=example/edited` |
| `suggestion_selected` | Accepted current-generation button action; `mode`, `choice_kind=original/suggestion` |
| `mode_changed` | Explicit mode switch; `mode=nepali_en/all_nepali` |
| `help_opened` | Help opened |
| `keyboard_settings_opened` | iOS accepts the explicit settings-open request; does not verify keyboard setup |

The prefilled example never emits `pad_used`. The funnel and copies chart exclude
copies of that example. Retention starts at first observed editing, with returns
to editing on later UTC days. Only sufficiently old cohorts can have D7/D30 results.
Suggestion taps measure interaction, not spelling accuracy. Mode selections count
explicit changes, not all typing in a mode. Keyboard setup interest and crash-free
sessions/latency are useful future dashboard additions; they are not inferred
from app opens or claimed as implemented quality metrics.

Typed text, outputs, candidate strings, clipboard values, text lengths, host-app
names, URLs and surrounding text are never passed to analytics. A before-send
allowlist rejects automatic events and removes SDK enrichment before persistence
and delivery. Screens, element autocapture, replay, automatic error tracking,
surveys, swizzling, feature-flag preloading and person enrichment are disabled.
The SDK may fetch public project configuration. Analytics events set
`$geoip_disable=true` and an empty `$ip`; the service necessarily receives network
requests. SDK queues provide bounded offline delivery and best-effort background
flushes ([SDK documentation](https://posthog.com/docs/libraries/ios)).

Help includes a usage-analytics switch and disclosure. Opting out persists,
prevents new capture, and closes the SDK; future launches leave it uninitialized
until re-enabled. Requests already in flight may finish. Previously collected
queued events can be delivered after re-enabling. The app's privacy manifest
lists product interaction and a random device identifier for analytics, with no
tracking. Keep the public privacy page and App Store privacy answers aligned
with this behavior when releasing the app.

### Verification

Run the privacy/deduplication checks from the repository root:

```sh
swiftc -D NEPTYPE_CONTAINER_TEST -module-cache-path /tmp/neptype-analytics-module-cache platforms/ios/NepTypeMobile/Analytics.swift platforms/ios/NepTypeMobile/Tests/AnalyticsTests.swift -o /tmp/neptype-analytics-tests
/tmp/neptype-analytics-tests
```

The existing simulator container harness additionally checks the disclosure and
persistent opt-out switch. It compiles without the SDK and sends no network events.
The separate SDK smoke app uses a temporary bundle ID and test events, so it does
not overwrite the normal app or enable the custom keyboard. All saved dashboard
queries were executed successfully; production results remain empty until an
instrumented Release device build is distributed.

## Product experience update

The cross-platform feature map, storage and privacy behavior, setup instructions,
validation status, and remaining native-host checks are documented in
[product experience](../../../docs/product-experience.md). Setup is always user-driven;
opening an app never registers or enables a system keyboard.
