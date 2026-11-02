# NepType input method — Phase 4 prototype

## Current status

The input method is a local InputMethodKit prototype, built from the shared offline language engine. A server-start check and automated composition-state tests can run without installation; these do not prove registration, candidate-panel behavior, text undo, focus changes or host-app compatibility. See the product plan for live test status. Commercial rights for the Aksharantar-derived index remain unresolved before distribution.

## Local installation and removal

1. Build with `bash scripts/build-input-source.sh` (Swift and Xcode command-line tools required). The local bundle is `build/NepType Input.app`; the build also stages an ad-hoc-signed copy in the system temporary directory and does not install it.
2. With the user's authorization, copy the signed bundle to `~/Library/Input Methods/NepType Input.app`. Do not overwrite an existing bundle without inspecting it. Sign-out/sign-in may be needed for macOS to discover it.
3. Open **System Settings → Keyboard → Text Input → Edit → +**, search for **NepType Nepali** under Nepali, and add it if listed. Switch back to your existing English input source via the input menu or the macOS input-source shortcut. This changes macOS input-source settings and must follow any system prompts.
4. To remove it, first switch to another input source; remove NepType in the same Input Sources settings, then remove `~/Library/Input Methods/NepType Input.app` after it is no longer active. Sign out and back in if it persists. Do not remove any other input methods.

If the bundle is not listed or the source is not functioning, keep the existing keyboard active and report the observed failure. Ad-hoc signing is for local testing; this is not a notarized distribution.

## Intended controls

- Select NepType via the macOS input menu; select the existing English/ABC input source to type English directly. macOS's configured input-source shortcut can switch between them.
- Roman letters are marked while composing. Space or punctuation commits; Tab/Shift-Tab cycles candidates; selecting a visible candidate commits it. Escape commits the original Roman word. Backspace edits the uncommitted Roman word.
- Arrow/navigation and modifier shortcuts commit the current word then pass the event to the host. Undo of committed text belongs to the host app and must be tested there; the IME does not implement a cross-app undo stack.
- The previous four Roman words may be retained **in memory only**, in that input session, to supply immediate context. They are cleared at punctuation, navigation, shortcuts, cancellation and deactivation. The app does not read surrounding document content, use global key monitoring or make network requests.

## Known limitations and test plan

The source uses word-at-a-time composition. URLs, email addresses and code typed character by character can be converted before they are recognizable as literals; use the English input source for them during testing. The standalone pad's literal protections do not automatically protect this IME path. Password and secure-field behavior is controlled by macOS/host apps and is unverified; do not assume this prototype can identify every sensitive field. Per-app event handling, candidate selection, cursor movement, focus loss, context clearing and host undo require real testing. InputMethodKit and individual applications may differ in their handling of marked text and multi-code-point Devanagari; this prototype has not yet established supported-app or macOS-version coverage.

Test in a disposable document: registration and switching; ordinary and mixed text; candidate choice and Escape; backspace; punctuation/space; cursor navigation; cut/paste and host undo; emoji and combining marks; focus changes between two applications; safe handling in secure fields; and uninstall/restart. Capture failures without copying private user text.

### Experimental manual language toggle (30 October 2026)

While NepType Input is active, Option-Z toggles Nepali/English for the current input session. The original Roman form of the current marked token is committed before switching; English mode passes subsequent keys through. The session switch and isolation are covered by unit tests. This is an early implementation: a visible mode indicator, configurable shortcut, persistence and a timed automatic-switch pause are not implemented. The shortcut, commit behavior and focus transitions have not been validated in actual host applications because installation and activation are pending approval; do not treat this as production ready.

### Token safety update

The uninstalled IME now keeps a contiguous token marked through punctuation until whitespace, so later characters can identify a URL, email, path or code identifier before commit. It preserves original Roman text on focus changes, cursor moves, shortcuts and language toggle; a partial Nepali word is therefore left Roman at those boundaries. Backtick-delimited spans are kept literal across spaces. The core regression suite passes, but real IMK clients are untested. Unquoted command words, escaped/nested backticks, manual early candidate selection, secure fields and host undo remain risks; English mode is safest for code.
