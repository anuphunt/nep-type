# Phase 0 evaluation, version 1

This evaluates the existing `NepaliCore.Transliterator` in Nepali mode. It does not modify its data or ranking. Run from the project root on macOS with Swift installed:

```sh
bash evaluation/phase0/run.sh > /tmp/neptype-baseline.json
```

The script compiles the current engine and evaluation runner into a temporary directory and cleans it afterward. Results are JSON containing each input, accepted sentence reference, actual rendering, exact-match status, and per-word annotations, top choice and the suggestions displayed in the standalone pad. `baseline-results.json` is the recorded run; a later run uses the then-current engine. Invalid case IDs, splits, token annotations or empty expected lists cause an error rather than silently dropping examples.

## Corpus and provenance

`corpus-v1.json` contains 25 explicitly annotated cases: 15 development/baseline examples and 10 frozen held-out examples. D01 is the user's specified product target; D02 is the user's reported typing example. They are included in this project for evaluation under the user's request. All other cases were authored synthetically for this task; no external corpus or private keystrokes were collected. Annotation and corpus are project material; distribution rights and ownership of all user-provided examples have not been separately established. No third-party dataset is included. Every case records its source, and no real contact details are used (`example.com` is illustrative).

The split was selected before measuring and no engine tuning occurred in Phase 0. Both splits are readable in this repository and have now been evaluated, so the held-out set is a **frozen comparison set**, not a blind independent test. Do not tune on it; create an independently collected, consented and sequestered test set for release-quality claims. The dataset is deliberately small and synthetic, not a representative sample of dialects or users. Spellings and role labels are provisional; a Nepali speaker should review them, especially where more than one rendering is valid. Do not turn these results into product accuracy claims.

## Scoring

- Each ordinary Roman token is manually annotated for its intended English or Nepali role in that particular sentence; repeated words have separate ordered annotations. URLs, emails and backtick code are protected spans, not scored as English words. Their preservation is checked by whole-sentence exact matching. Emoji, whitespace, numbers, existing Devanagari and punctuation are also assessed through that sentence check.
- **English preservation:** count English-labeled tokens whose top candidate is one of their accepted references, divided by English-labeled tokens. Correcting an English word to Devanagari is an error in that context, including ambiguous `man` or `football`.
- **Nepali top-1:** count Nepali-labeled tokens whose top candidate matches any annotated accepted Nepali spelling, divided by Nepali-labeled tokens. Annotated variants are alternatives, not separate successes.
- **Visible candidate availability:** per role, the number of tokens for which any acceptable reference appears in the standalone pad's candidate row (first four engine candidates, plus the original if missing). For English words the original is always a candidate, so this measures recoverability, not automatic detection. It does not measure the input-method UI, which is unverified.
- **Sentence exact:** whole rendering matches one of the listed sentence references under canonical Unicode normalization. This is a stricter diagnostic; only listed whole-sentence alternatives count, so it can undercount valid combinations of token-level alternatives. All counts are case-sensitive except Unicode canonical normalization. No latency, user correction effort, live-key performance or real-world generalization is established by this run.

## Baseline

Run date: 2026-10-29, Apple M4 Max, arm64, macOS 26.6.2, Swift 6.4, optimized command-line build. Engine `Transliterator.swift` SHA-256: `e06350214c8b91cdee8acaea9ceefb0660db88ce94af7389470501d9f3eea03c`. Corpus SHA-256: `0941853bc58bae0bb8c2a56ee5cdc70dacc3ff6e433f38216d16c2c9c1ed00e4`.

| Metric | Development | Frozen comparison |
| --- | ---: | ---: |
| Sentence exact | 10/15 (66.7%) | 2/10 (20.0%) |
| English preservation, top 1 | 11/19 (57.9%) | 7/15 (46.7%) |
| Nepali word, top 1 | 40/42 (95.2%) | 22/28 (78.6%) |
| English acceptable candidate visible | 19/19 (100%) | 15/15 (100%) |
| Nepali acceptable candidate visible | 41/42 (97.6%) | 22/28 (78.6%) |

For the user's target, the current output is `आज मेरो फोने को बत्तेर्य लितेरल्ल्य देअद भैसकेको थियो`, rather than the target in the product plan. An English `man` becomes `मन`, while `pani` defaults to `पनि` even where the intended word is `पानी`; selecting an alternative can correct both. `football` offers `फुटबल` and the original `football` in both contexts. These examples show why independent context-sensitive evaluation is needed.

**Review before Phase 1:** confirm which spelling conventions and acceptable alternatives should be used; agree how to annotate ambiguous words, whether primary goals are token or sentence quality, dataset ownership and permission for future real examples, and numeric targets. This first evaluation is reproducible, but those decisions remain open; no later phase is started by recording it.

**Phase 2 note:** `evaluation/phase0/run.sh` and its original token-level scoring predate contextual selection; it does not reorder per-word candidates using sentence context. For the current engine, use `evaluation/phase2/run.sh`, which scores the same corpus with the same context and candidate ordering as the standalone pad. The historical `baseline-results.json` remains unchanged.
