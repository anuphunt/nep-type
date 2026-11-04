# Windows keyboard release acceptance

Record build SHA, Windows version/architecture, app version, input layout and exact results. All rows below are **NOT RUN** until desktop evidence is attached. Native TSF/portable tests are recorded separately; they do not fill these rows.

| Area | Required check | Status |
| --- | --- | --- |
| Clean install | Install on a clean Windows 10/11 account; Nepali profile appears; Win+Space switches both ways; normal default remains | NOT RUN |
| Notepad | `namaste ma office janchu`, repeated identical words, punctuation, numbers and URLs; no duplicates/lost text | NOT RUN |
| Word / Office | Same text; Enter/Tab, selection replacement, mouse selection, Ctrl+Z/redo, rich formatting; native undo grouping | NOT RUN |
| Chromium | Textarea, contenteditable, document editor, forms, autocomplete and composition events | NOT RUN |
| Firefox | Same browser checks, including selection and composing event behavior | NOT RUN |
| Secure / literal | Password, PIN, URL/email/number fields, disabled/read-only edits remain literal; engine never sees protected text | NOT RUN |
| Editing | Backspace to empty; delete before/after a commit; Home/End/arrows; selected text; mouse cursor move during a word | NOT RUN |
| Choices | Visible default, original Ctrl+1, Ctrl+2–4, Up/Down, Escape, repeated/held keys and stale choices | NOT RUN |
| Modes | Ctrl+Shift+Space cycles Mixed/Nepali/English; modifiers, AltGr, dead keys, non-US layouts and Caps Lock | NOT RUN |
| Focus | Switch fields, tabs, apps and IMEs mid-word; original retained, composition ends, popup disappears | NOT RUN |
| Recovery | Host rejects lock/edit/composition; app closes/crashes mid-word; no deferred replay; new contexts recover | NOT RUN |
| Accessibility | Screen reader announces choices; high contrast, 100/150/200% DPI, multi-monitor bounds | NOT RUN |
| Privacy | Offline network capture; no typed-text logs, clipboard changes or unexpected files | NOT RUN |
| Distribution | Signed installer/DLL, upgrade, rollback, unregister, locked DLLs, restart/sign-out | NOT RUN |
| Architectures | Native x64 and ARM64 independently; explicitly document x86 application coverage | NOT RUN |

The Mac keyboard is outside this Windows acceptance matrix. The product owner has confirmed it works; stale Mac prototype notes do not override that testing.
