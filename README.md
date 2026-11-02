# NepType

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Brand name: **NepType** (capital N and T). Logo concepts and brand guidance are in [branding/README.md](branding/README.md).

A native macOS Nepali typing prototype, built with Swift and AppKit. Everything runs locally. There are no model downloads, accounts, telemetry, or network requests. The project includes a pinned CMU English dictionary; see `evaluation/phase1/REPORT.md` and `data/sources/CMUDICT-LICENSE.txt`.

## Free and open source

NepType is free to use, with no license fee or subscription. Its project-authored code, documentation, artwork, and authored vocabulary are available under the [MIT license](LICENSE). You can use, study, modify, and redistribute that work, including commercially, while retaining the copyright and license notice.

Bundled third-party dictionaries and derived indexes retain their own terms. In particular, redistribution rights for the included Aksharantar index remain unresolved; MIT does not clear that resource. See [third-party notices](THIRD_PARTY_NOTICES.md) before redistributing a build or dataset.

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for reporting typing issues and submitting changes.

## Run

Double-click `build/NepType.app`, or run:

```sh
bash scripts/run.sh
```

To rebuild or test (Xcode command-line tools required):

```sh
bash scripts/build.sh
swift test
build/NepType.app/Contents/MacOS/NepType --smoke-test evidence
```

## Try it

The Mac typing pad uses a Graphite palette: Roman input, a horizontal suggestion row, and Nepali output in a 720 × 540-point workspace. The output automatically scrolls to follow your typing position in long paragraphs. The help button opens output-mode guidance, text-size settings, and the quick guide; typing settings are also available with **⌘,**.

- Type `ma office janchu` → `म office जान्छु`.
- Type `bholi meeting pachi bhetau` → `भोलि meeting पछि भेटौँ`.
- Put the cursor in `pani` and choose `पनि` or `पानी`; the original `pani` is also a choice.
- Choose **Nepali + EN** to keep recognized English words, or **All Nepali** to write them in Nepali letters too. The original Roman word remains available in the suggestions.
- Use **Copy text** to paste the output into Messages, Notes, a browser, or any other app. **Edit → Copy Original** copies Roman text.
- Undo and redo cover text edits, candidate choices, clear, and output-mode changes. History lives only in memory, up to 200 changes.

Shortcuts: **⌘⇧Space** switches languages, **⌥1–5** chooses a suggestion, **⌘Z/⌘⇧Z** undo/redo, and **⌘⇧C** copies the output. Native cut/copy/paste/select-all work in the editor.

## Scope and limits

The standalone pad works today. A separate experimental InputMethodKit input source is in `build/NepType Input.app`. It has been compiled but has not yet been installed, activated, or tested in other apps; its registration and typing behavior remain unverified. It is not installed automatically.

To try the experimental input source, copy `build/NepType Input.app` to `~/Library/Input Methods/`, log out and back in if needed, then open System Settings → Keyboard → Text Input → Edit → Add Input Source and search for NepType under Nepali. Use the macOS input menu to switch between it and your normal English keyboard. Type a Roman word, press Tab to cycle alternatives (including the original), Space to commit, or Escape to keep the original. Backspace edits the current Roman word. If it fails to appear, remove the app from `~/Library/Input Methods/` and log out and back in. These steps are experimental and have not been verified on this Mac.

Rebuild the input source with `bash scripts/build-input-source.sh`. It does not request Accessibility or Input Monitoring permission.

Transliteration uses local English and Nepali indexes, simple neighboring-word evidence, and deterministic phonetic fallback. These evidence scores are hand-authored rules, not AI probabilities or a trained language model. The candidate row also shows lower-confidence pronunciation-derived Nepali suggestions marked with a dot (·) and Aksharantar-derived alternatives marked with a dagger (†). It is not AI language detection, translation, or a comprehensive dictionary. Unfamiliar names, long vowels, retroflex consonants, nasalization, and mixed English may need corrections. Candidate choices apply to individual word occurrences. Editing a word invalidates its saved choice and choices after it, to avoid assigning a choice to the wrong word.

English/Nepali switching applies to the whole preview. In Nepali mode, a small hand-written English list and uppercase acronyms stay in Roman letters; a Nepali word list supplies common spellings, and unrecognized words are converted using phonetic rules. This is not automatic language detection, so unlisted English words may be converted and ambiguous words can be guessed incorrectly. Choose the original Roman word in the suggestions to correct a word. For example, `football` becomes `फुटबल` by default, with `football` also offered as a suggestion. URLs, email addresses, inline backtick code, numbers, existing Devanagari, whitespace, and emoji are preserved. This is not a full code-editor parser. The app does not save documents between launches; copy text you want to keep before quitting.

## Structure

- `Sources/NepaliCore`: transliteration, tokenization, candidate choices, undo/redo.
- `Sources/NepaliKeyboard`: native UI, shortcuts, clipboard, UI smoke test.
- `Tests/NepaliCoreTests`: phrase correctness, literal preservation, UTF-16 cursor positions, history, and choice invalidation.
- `scripts/build.sh`: builds a local app bundle and applies an ad-hoc signature. No paid signing account is required for this local prototype.
- `evidence`: generated app screenshot and UI smoke-test results.

No ViKey or other GPL code was used. The app includes derived CMU English, Google Nepali and Aksharantar IndicCorp-labeled data; their source and attribution notices are bundled in `Contents/Resources/Licenses`. Aksharantar commercial redistribution rights are unresolved and must be reviewed before distribution. No model is bundled.

The Phase 1 English dictionary is exposed as offline membership evidence but is not yet used to change typing decisions; curated Nepali first choices remain the original small handwritten vocabulary; the Google-derived index adds marked suggestions only. See `evaluation/phase1/REPORT.md` for coverage and source limitations.

Rebuild the reproducible candidate resources with `python3 scripts/build-indexes.py` and `python3 scripts/build-google-aliases.py`. The latter checks the pinned source hash and rebuilds `data/compiled/google-ne-aliases.tsv`. The original Google source and attribution are under `data/sources/`. See `evaluation/phase1/REPORT.md` for quality and licensing details.

Aksharantar IndicCorp-labeled training pairs are included in the normal local app by user request. `†` marks those suggestions. The local context rules may choose a unique matching entry automatically; the original input remains available. The candidate row says UNSURE when the rules cannot make a confident choice, though the preview may still use a phonetic fallback. The index can be regenerated from the pinned archive using `python3 scripts/build-aksharantar-index.py /path/to/nep.zip`. It is an exact-match index, not a language model, frequency list, or guarantee of good coverage. The project owner will handle unresolved commercial licensing before distribution; no commercial clearance is asserted. See `evaluation/phase1/REPORT.md`.

The [Phase 2 evaluation](evaluation/phase2/README.md) records mixed-language comparisons, known regressions for out-of-index names, and performance limits. The experimental input-source bundle has not been updated or installed as part of Phase 2.
