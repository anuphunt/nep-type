# NepType iOS experimental keyboard

**Current behavior:** The security-review section at the end supersedes earlier dated experiment descriptions. The production proxy now pauses when ownership is uncertain; earlier descriptions of committing on callbacks are historical.

This project builds a container and an iOS custom-keyboard extension with the same shared Rust engine and embedded dictionary as the Mac prototype. Roman text is displayed as marked text; tap a candidate to select it, then use Space or Return to commit it. The selected candidate is highlighted while the text remains Roman until acceptance. Delete restores the exact Roman token while a preview is active; without a preview, Space commits the original. The language toggle switches to literal English. It does not request Full Access. No keyboard has been installed or enabled, and its behavior in a real host has not been verified; it is not production-ready.

The app and extension now reference `Sources/NepaliCore` and canonical dictionaries directly from this repository. There are no maintained SharedCore or resource snapshots. `sync-core.sh --check` (and the compatibility `--sync` spelling) verifies those references and dictionary hashes; it no longer copies files. Keep the repository structure intact when opening Xcode. `Tests/run-core.sh` exercises the canonical core as a macOS process. See [shared-engine architecture](../../shared/README.md).

A generic iOS Simulator build succeeded using Xcode 27.1 with signing disabled. The compiled extension is roughly 107 MB uncompressed: about 94 MB of Aksharantar data, 10 MB of Google aliases and the executable/other resources. The core uses memory-mapped index files, but actual iOS extension peak memory, startup, latency and termination behavior have not been measured. A macOS process running the snapshot's first small composition sequence took 56 ms; this is not an iOS benchmark. Simulator devices exist outside the sandbox; the build was not installed and its keyboard was not activated or exercised.

Known limitations: UIKit marked-text behavior across applications, caret movement, focus changes and extension dismissal remain untested and may lose or alter composition; the keyboard must not be treated as safe for real use yet. A basic numbers/symbols page is available, but it does not cover a full iOS keyboard. No system candidate bar, automatic language choice, complete accessibility or host-specific return actions. Views are recreated per key and performance is unmeasured. Android, Windows and Linux integration are separate. Data provenance notices and manifest accompany resources; commercial licensing remains the user's unresolved pre-distribution task.

## In-process simulator host experiment

`Tests/SimulatorHost/run.sh BOOTED_SIMULATOR_UDID` builds and temporarily installs a standalone test app with no keyboard extension, then removes it. It drives the actual keyboard controller's buttons against a real `UITextView` via an injected editor. It does not enable a system input method or change keyboard settings. It refuses to replace an existing app with its test bundle ID. The test invokes `selectionWillChange` directly before moving the caret to model an external system callback; it cannot establish whether or when the real extension receives that callback. The first run exposed a misplaced-space bug after a caret move. The controller now commits original marked text on the callback before selection moves, and avoids acting on synchronous callbacks during its own edits. Typing, candidate choice, English, deletion, space, a simulated callback plus caret move, and focus-loss preservation passed in the in-process host. Real keyboard extension connection, asynchronous callback ordering, cursor and selection ownership, secure fields, other hosts, memory and interruption remain unverified; do not consider this safe for production use.

The language and shift controls expose their current state to accessibility services; candidate hints distinguish keeping the original from replacing it. The latest in-process run passed 25 checks, including control bounds at 320- and 430-point widths and the language and shift accessibility values. This checks exposed properties and basic geometry only: VoiceOver navigation and announcements, larger accessibility text, touch-target ergonomics, actual extension sizing and host integration still require device testing. The temporary simulator host was removed after the run.

The number/symbol toggle, identifier preservation, shift and deleting a whole active composition were added to the simulator host. The latest in-process run passed 16 checks. This does not test the system-extension connection or establish safe host callback behavior. The view uses system background colors for appearance changes, but dark mode, dynamic text and touch target sizing have not been visually verified.

## Asynchronous candidate lookup

Candidate lookups now run on a serial background operation queue. The keyboard immediately offers the original Roman token while a lookup is pending; a generation check, token snapshot and operation cancellation prevent late results from updating a different composition. Candidate conversion still requires an explicit tap. The simulator host passed 19 checks, including a deliberately delayed lookup whose word was already committed. This tests a `UITextView`-backed in-process editor, not an installed extension. Real extension lifecycle, callback ordering, timing, memory pressure and candidate accessibility remain unverified. The test-only delay hook is used solely by the host harness.

An actual system-extension test requires the keyboard to be added and enabled in the simulator's keyboard settings. No such settings were changed; approval for input-source activation remains pending. The temporary standalone test host contained no keyboard extension and was removed after the test.

## Candidate preview and correction

Candidate selection now changes only marked text. Delete restores the original Roman token before it is committed, and a second Delete removes a Roman character. Space or Return accepts the preview; editing or focus change preserves the Roman input. This is pre-commit correction only: no attempt is made to replace committed host text, and post-commit undo is not implemented. An in-process simulator host passed 29 checks including preview, Delete-to-restore, reselect and a queued stale candidate tap after the token changed. Candidate buttons carry a generation guard. The generic simulator extension build succeeded. Real system extension marked-text ownership and callbacks remain unverified, so this must not be treated as safe for daily use.

## Post-commit correction safety

API source: [Apple UITextDocumentProxy documentation](https://developer.apple.com/documentation/uikit/uitextdocumentproxy), and the installed iOS 27.0 Simulator SDK header `UIKit.framework/Headers/UIInputViewController.h` (the `UITextDocumentProxy` declaration). The host-race conclusion below is our engineering inference from that interface, not a claim that Apple documents a specific race.

Post-commit undo is deliberately unavailable. The iOS `UITextDocumentProxy` interface exposes nullable context snapshots, a nullable selection and character-level deletion/insertion, but no atomic compare-and-replace operation for a previously committed owned range. An unchanged-looking suffix or document identifier alone cannot prove the caret and surrounding text have remained unchanged between inspection and deletion, nor that multiple deletions will be atomic. Rewriting a committed word on that basis could modify unrelated text. Until a host-safe transaction can be demonstrated, choose a marked candidate preview and press Delete to recover the original **before** Space/Return commits it. After commit, Delete is ordinary host deletion; the keyboard never automatically rewrites the preceding word.

The in-process simulator host now includes regression checks that a queued candidate tap after commit does not rewrite committed text and that Delete after commit performs ordinary deletion without restoring/replacing surrounding text. It passed 32 checks on an iPhone 17 Pro simulator. The host explicitly simulates selection callbacks, so this does not verify system-extension behavior, asynchronous focus changes, secure fields or every host editor. The temporary host app was removed; no keyboard was enabled.

## Literal-field guard

The keyboard now uses literal input and hides candidate choices when the host reports a secure/password/one-time-code field or a URL, email, phone or numeric keyboard type. Its language toggle is unavailable while that guard is active and the user's prior language selection is retained. A queued candidate is ignored and a pending preview is not accepted in a literal field. This uses host-reported traits and is not a security guarantee: apps can misdeclare traits, iOS may exclude third-party keyboards from secure fields, and actual system-extension focus, trait changes and callback ordering have not been verified. The in-process simulator host passed 40 checks, including injected literal-field behavior and trait classifier checks; it does not verify the actual proxy traits in another app. No keyboard was enabled.

## Literal-field transition safety review

If a host changes the proxy to a literal-only field while a Roman token from the prior field is still marked, the controller now discards only its in-memory composition and cancels pending candidate work before inserting a boundary or processing Delete in the new field. It does not insert that prior token into the new protected field. This is a fail-closed tradeoff: the old field may retain an unresolved marked span, and if the old host abandons that span its text may be lost. The in-process `UITextView` test host exercises an injected editor change without the usual selection callback: Space and Delete target the new field without inserting the prior token. This does not verify real system-extension ownership, host callbacks, secure field traits or cross-app transitions; hosts may omit or misreport traits, and non-literal focus changes still require real-host verification.

## Document ownership review

The experimental controller binds a marked token to `UITextDocumentProxy.documentIdentifier` and checks that identifier before candidate selection, edits, commit or boundary handling. If it changes or is unavailable, it drops the old in-memory token and never inserts it into the newly observed document. Candidate selections now highlight in the keyboard only; the host keeps Roman marked text until Space/Return explicitly accepts a conversion. Stale candidate buttons retain their generation guard. On external `textWillChange`/`textDidChange`, the controller abandons in-memory composition without writing; an asynchronous callback from its own operation may therefore end composition early. On a selection callback or disappearance it commits Roman only when the document identifier still matches.

The temporary standalone simulator host passed 48 checks, including a real old candidate button delivered after a no-callback switch to a different test document and preserving the old Roman mark. The host uses distinct test UUIDs and explicitly invokes callbacks. A document identifier is **not proof of the active field or an owned marked range**: different fields may share one identifier, the host may change the caret/mark with no callback, callbacks may be delayed, and the proxy has no atomic ownership check. Selection/disappearance paths can still write into an unexpected field that shares the same identifier, and the previous mark may remain unresolved or be lost after abandoning. Real system-extension callbacks, multiple fields within one document, secure contexts and host behavior remain unverified. Do not use for important or sensitive input.

## Candidate paging and simulator activation

The candidate strip displays up to three Nepali alternatives and always keeps the original Roman token visible. If more alternatives are available, **Previous suggestions** and **More suggestions** move backward and forward through pages. Moving to a new page clears a previously selected preview so an invisible selection cannot be accepted accidentally. Buttons are tied to each render generation; queued taps from an earlier token or page are ignored. The generic simulator extension build passed, and the standalone in-process simulator host passed 58 checks including forward and reverse page navigation, 44-point minimum candidate-control widths at 320 points, original visibility, stale page taps and clearing an invisible preview. This is not a system extension host test.

Apple's [custom-keyboard documentation](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard) says the user adds a custom keyboard through Settings > General > Keyboard > Keyboards > Add New Keyboard. Actual extension-host testing would require installing the development container app in the simulator and enabling/selecting the keyboard there. No simulator keyboard or host input source was enabled for these tests. This activation requires the pending user approval; do not change simulator keyboard settings without it. Real host composition ownership, focus/caret callbacks, secure-field behavior and accessibility remain unverified.

A queued ordinary key action now carries the same render generation guard used by candidate controls. The in-process simulator host verifies that a stale Space action from an earlier render does not commit a newer word. This guards render changes only; a document switch without a rerender and actual extension callback timing remain unverified.
Because lookup completion also re-renders controls, the conservative guard may discard a touch that was queued during a refresh. Real touch responsiveness should be tested on devices before use.

## Security review: same-document field changes

A simulator regression reproduced an unintended marked-text write when a selection callback arrived after the active editor changed to another field sharing the same coarse document identifier. The production proxy cannot prove the identity of the selected field. It now pauses editing with an on-screen instruction to switch keyboards whenever an external selection or text callback occurs during composition, or the keyboard disappears during composition. It retains the Roman token in memory, invalidates candidate work, and rejects further text-edit actions; it does not automatically copy or rewrite text. Repeated callbacks and stale candidate taps must not resume edits. This intentionally may pause on delayed callbacks from the keyboard's own earlier edits. A system keyboard switch or host resolution may still leave the old marked token unresolved or lost. Actual extension/host callbacks, recovery and secure fields remain unverified; do not use it for important text.

The injected UITextView test editor can positively identify its exact field, so the simulator harness retains a same-field caret-movement path for that artificial case. The production document proxy always declines that identity claim and takes the conservative pause path. The test-only host models host resolution and a fresh controller explicitly; it does not prove that real iOS can recover a retained composition. The temporary test app is removed after each run.

For build diagnostics, the app and extension now both declare development marketing version `0.1.0` and build `1`. This only removes the mismatched/missing version warning; it does not make the build signed, validated for distribution, or release-ready.

## Explicit on-screen recovery when ownership is uncertain

When the controller has paused with an uncommitted Roman token, a **Show retained Roman text** control is available only while the current field is not host-reported as literal or protected. It displays the token in the keyboard view after an explicit tap so the user can manually recover it; **Hide** removes it from the view. It never writes into the host, clipboard or local storage. The token is hidden by default and again after an external callback, trait change, dismissal or session teardown. Queued stale reveal actions are ignored. This deliberately exposes the token on screen, including to assistive technology after the user's action; it may be visible to others. Host traits and callback delivery can be missing or wrong. It cannot restore an old mark or guarantee the token survives extension termination; a same-document field transition without any callback cannot be detected reliably.

The in-process simulator host passed 74 checks, including explicit reveal/hide, default concealment, stale taps, literal-field suppression and no writes to the newly focused `UITextView`. This is not a real system keyboard extension test. We did not use the clipboard: Apple's archived [custom keyboard guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) lists `UIPasteboard` as an Open Access capability, whereas this extension does not request Open Access. Actual extension behavior and privacy require native host testing.

## Candidate selection feedback

The selected spelling is highlighted in blue with white text and exposed as selected to accessibility; the original Roman token is selected by default. Selecting an alternative does not rewrite the marked text until Space or Return. Delete clears the selection, and changing pages clears an invisible selection. The standalone simulator host passed 78 checks, including selection feedback, stale actions and modeled focus changes; this does not validate the system keyboard extension or VoiceOver behavior in other apps.

## Additional symbols

The experimental keyboard now has a second symbols page reached with `#+=` and a return control labeled `123`. It supplies characters such as `#`, `_`, brackets and `+` in English and Nepali modes. A stale page button is rejected after a rerender. The temporary injected UITextView simulator host passed 82 checks, including both language modes, page switching and a 320-point layout check; the generic simulator app/extension compiled. This is not a test of an enabled system extension, VoiceOver or third-party editors, and touch target usability still needs device testing. No keyboard was enabled.

## Cursor controls

When there is no active composition, left/right controls in the top row request movement by one adjacent grapheme using the host's surrounding-text context. They are unavailable during a marked word and reject stale taps. If context is absent, they do nothing. The injected UITextView host passed 88 checks, including English, an emoji, a Devanagari combining sequence, missing context and stale taps. The unsigned generic simulator app/extension compiled. Actual system-proxy offset behavior, truncated context, selections, accessibility and third-party hosts remain unverified; truncated context can yield an incomplete grapheme and movement may not match intent. No keyboard was enabled.


## All Nepali suggestions

The idle suggestion row has an All control that selects All Nepali suggestions; its accessibility value reports On or Off. The language switch retains literal English. In All Nepali, the original Roman mark remains the default: choose a suggested spelling before Space or Return to commit it. This protects the existing preview workflow; it is not automatic conversion. The injected UITextView simulator host passed 97 checks, including the new mode, a candidate commit, original availability, stale controls, a literal field and narrow layout. The actual enabled extension, VoiceOver, physical touch interaction and third-party host behavior remain unverified.

## iPhone keyboard layout matching

The extension now follows the supplied iPhone keyboard reference: a 44-point prediction row, fixed QWERTY key pitches, half-key home-row stagger, centered third row, rounded borderless keycaps, and a large blank spacebar between 123 and Return. Its preferred portrait content height is 271 points; compact phone landscape uses 218 points. Host light/dark keyboard appearance and requested sentence capitalization are respected. The standalone typing pad keeps its own layout.

The compact अA control switches Nepali/English on tap. Touch and hold it for All Nepali and cursor options. During composition, swipe the three prediction slots to page through alternatives, or use the same menu's Previous/More actions. The original Roman spelling remains in the first slot on every page. A later lookup cannot move the key grid. Globe-key handling still uses UIKit's required input-mode switcher behavior; this UI does not draw a replacement system dictation control.

The simulator harness exercises the real buttons and menu actions, stale actions, correction/recovery safeguards, host capitalization, light appearance, and key geometry at 320, 393, and 430 points. Its keyboard-only screenshots are saved under evidence/native-keyboard/. These are injected-editor checks, not verification of real system-extension callbacks, dictation, QuickPath, or host-specific behavior.

## TestFlight app identity

The registered TestFlight app is Apple ID 6829130224, bundle ID `app.lekha.prototype`,
with extension ID `app.lekha.prototype.keyboard`. These stable identifiers are kept
through the NepType rebrand so installed testers receive updates. The Xcode project
defines `NEPTYPE_APP_BUNDLE_IDENTIFIER` once and derives the extension identifier
from it. Product names, icons and display names remain NepType. Version 0.1.0 build 2
includes the native keyboard layout updates and canonical shared engine/dictionaries.

Build 3 sets the installed app display name to exactly `NepType`. The App Store
Connect/TestFlight listing was also renamed to `NepType`; the registered bundle
identifiers stay stable for existing testers.
