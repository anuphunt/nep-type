# NepType platform feasibility notes — 30 October 2026

These are implementation proposals based on platform documentation, not demonstrated builds. Existing NepType is a Swift macOS application and experimental InputMethodKit service. Do not claim system or cross-platform compatibility until tested in actual hosts. ViKey's release claims and NepType's target matrix are in NEPTYPE_PRODUCT_PLAN.md.

## Shared boundary

Define a deterministic engine API with one session per focus/client: create/reset, append and edit composition, get candidates including raw input, select, commit/cancel, set language and pass only limited in-memory context. Version index files and ensure identical normalization, ranking and corpus results across platforms. Test Unicode/UTF-16 index conversions, focus loss, multi-client isolation, stale updates and corrupted/missing indexes. A separate adapter should own OS event delivery and native preedit/commit mechanics; the engine must not read host text or network. Benchmark loading time, peak memory, package size and per-keystroke p50/p95 on target hardware; the large Aksharantar data can materially affect mobile memory and storage.

The current Swift implementation is not automatically portable: Foundation, native build/packaging, data access and calling convention need validation for every target. Compare a small portable core with a stable C ABI against platform-specific ports, using the same executable conformance corpus before committing to a rewrite. Protect current macOS behavior and do not imply cross-platform feature parity from shared tests alone.

## Windows

Microsoft documents [Text Services Framework](https://learn.microsoft.com/en-us/windows/win32/tsf/text-services-framework) for text services including keyboard processors. Prototype a TSF text service and settings application; map composition and candidate selection through the TSF document interfaces, preserve focus and context per client, and let host shortcuts through. Validate 64-bit and ARM64 registration and versioning separately; determine whether any 32-bit processes are in the supported matrix. Exercise composition/selection/undo in Notepad, Office, Chromium and Firefox, password fields, elevated and secure desktops, RDP, app switching, layout switching, accessibility, crash and uninstall. These are proposed tests, not verified current behavior. Native Windows build infrastructure, actual Windows test hosts and signing/distribution decisions are required.

## Linux

[IBusEngine](https://ibus.github.io/docs/ibus-1.5/IBusEngine.html) provides an engine extension point; [Fcitx 5](https://fcitx-im.org/) has its own addon system. Start with one framework as a bounded prototype, keeping the engine independent, and add the other only with a maintained adapter. Test Ubuntu/Debian/Fedora; GNOME and KDE; X11 and Wayland; GTK, Qt, Chromium/Firefox and terminal clients; each supported x64/ARM64 package. Verify preedit, candidate navigation, focus, undo, secure fields, other IMEs, removal and clean upgrade. Framework, compositor and application behavior varies; the matrix must name exact versions rather than claiming universal Linux support. Build environments with the relevant development headers and actual desktop sessions are needed.

## Android

Android documents an [input method service](https://developer.android.com/develop/ui/views/touch-and-input/creating-input-method) that is selected by users in system settings. Implement a native InputMethodService, keyboard view, language control, raw-text alternative and candidate strip. The adapter must handle selection updates, input types, composing/committed text, lifecycle restarts, external keyboards and application compatibility. Test physical/emulated devices, TalkBack, rotation, dark mode, large text, password and numeric fields, clipboard and privacy, offline airplane mode, memory pressure, and app process death. A compatible JDK, Android SDK/Gradle and device or emulator are prerequisites; download and installation of these tools require the applicable environment approvals. Investigate target SDK and store requirements at release time.

## iOS

The installed Xcode lists iOS and simulator SDKs, but the sandboxed `xcrun simctl list devices available` failed to connect to CoreSimulatorService and could not write its log (Operation not permitted). This does not establish that simulator runtimes are absent. Prototype a keyboard extension and container app, then test actual system restrictions, keyboard enabling, text input contexts and lifecycle on approved simulator/device setups. Site lists iOS as forthcoming, not released. Signing and distribution accounts and system activation must be handled separately.

## Local tool observations

On this Mac: Apple Silicon Darwin; Xcode 27.1 with Swift 6.4 and iOS/macOS SDKs. The current shell path did not resolve `cargo`, `rustc`, `cmake`, `ninja`, `kotlinc`, `adb`, `emulator`, `gradle`, `docker`, Windows cross compiler or Wine. `/usr/bin/java` exists but `java -version` says no Java runtime is available. Common Android SDK and Android Studio locations checked were absent. These observations do not prove no alternate installations exist. No tools or input sources were installed or system settings changed for this investigation.
