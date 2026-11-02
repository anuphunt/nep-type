# Phase 2: local context prototype

## Behavior

The standalone pad uses handwritten evidence scores to select a first choice for each Roman word. A curated Nepali entry, English allowlist, CMU English membership and a unique Aksharantar match provide different amounts of evidence. Immediate neighboring words add evidence when they are classified as strong local English or Nepali anchors; a small set of English determiners adds extra English evidence. Evidence does not cross punctuation, newlines or protected literal tokens. Scores are heuristic rules, **not probabilities** and not learned or frequency-based. No per-user learning or network service is included.

When English evidence wins, the original Roman text is the first choice. When Nepali evidence wins, the curated or unique Aksharantar candidate is first. When neither has adequate evidence, the original or phonetic fallback is chosen and the active candidate row says **UNSURE — CHOOSE**. A phonetic fallback can be incorrect; uncertain is not a guarantee that text remains Roman. The original Roman text and alternatives remain selectable. The input is retained separately from its derived preview, manual choices are undoable, and edits can invalidate later manual choices to avoid applying them to the wrong word. This remains an in-app preview rather than a system-wide input method.

URLs, email addresses, backtick inline and fenced code, contractions and hyphenated/underscored letter strings are protected. This is not a full parser for all programming languages or every sensitive field. No data is transmitted or retained for model learning.

## Measurement

On the earlier 10-case Phase 0 comparison split, English top-1 preservation was 7/15 in Phase 1, 13/15 in the dataset-first test, and 15/15 with this context prototype; Nepali top-1 was 22/28 for all three. Exact sentences were 2/10, 4/10 and 5/10. Visible Nepali candidate availability was 26/28 for all three. See `phase0-context.json` and the earlier phase0/dataset-first result files. These examples are few, provisional, have already been inspected and cannot support general accuracy claims.

`mixed-v1.json` adds 20 synthetic sentences (34 English and 43 Nepali annotated word occurrences), authored after initial heuristic development and before evaluating this corpus. It is a new check, **not a blinded or independently speaker-reviewed holdout**. Results are:

| Measure | Phase 1 | Dataset-first test | Context prototype |
| --- | ---: | ---: | ---: |
| English top-1 | 20/34 | 31/34 | 34/34 |
| Nepali top-1 | 40/43 | 40/43 | 40/43 |
| Exact sentences | 9/20 | 14/20 | 17/20 |
| Intended Nepali candidate visible | 41/43 | 41/43 | 41/43 |

This is not proof of production quality. Examples of remaining failures are `ma pani khanchu` → `म पनि खान्छु` when water was intended, `hami school janchau` → `हामी school जन्चौ`, and `usko ghar sundar cha` → `उस्को घर सुन्दर छ`. The user's longer phone example becomes `आज मेरो phone को battery literally dead भैसकेको थियो`; the intended `भइसकेको` remains a selectable alternative rather than the default. Context evidence is limited to immediate neighbors and cannot resolve meaning reliably; token casing, names, unsupported spellings, code, and English word overlaps can still fail.

On the separate Aksharantar test split (4,101 isolated words, including foreign names expected in Devanagari), top-1 exact results were 430/4,101 for Phase 1, 395/4,101 for the dataset-first test, and **367/4,101** for the context prototype. The source training index has no matching Roman keys for those test items. This is a real regression on an important out-of-index and names test. Since each item is isolated, it does not measure sentence context; it does show that English preservation can wrongly leave names in Roman text and that phonetic fallback is weak. Do not interpret this result as mixed-sentence accuracy.

The standalone app passed 15 Swift unit tests and 24 UI smoke checks covering ambiguous `man`, candidates and undo, uncertainty indication, English mode, wrapping and clipboard. On Apple M4 Max, macOS 26.6.2, Swift 6.4, a simulated edit through the actual text-change delegate and layout/display path (30 warm runs each) measured: 9-word sample p50 0.930 ms / p95 1.138 ms / p99 1.408 ms; 99-word sample p50 4.159 ms / p95 4.667 ms / p99 4.841 ms. These measurements exclude OS key event delivery, cold start, other apps and larger documents; p99 is the maximum of only 30 samples. See `evidence/ui-smoke-test.json`.

Run `bash evaluation/phase2/run.sh` for the Phase 0 corpus, or pass `evaluation/phase2/mixed-v1.json`. Results contain per-case output, candidate choices and uncertainty. The code and generated data are local. The official word-test comparison uses the pinned Aksharantar test archive as documented in Phase 1.

## Status

The Phase 2 **prototype is implemented**, but acceptance and quality thresholds remain open. A larger independently collected, consented, speaker-reviewed bilingual evaluation is needed, especially for ambiguous words, proper names and failures noted above. Aksharantar commercial rights and underlying source provenance remain unresolved before distribution. System input-source registration was not performed. No optional model, remote fallback or subsequent phase was started.

Recorded source SHA-256: `3852a1333fffd5d81b5487e973e927843de7e790af842d0430bc2bdbe3e3a756` (`Sources/NepaliCore/Transliterator.swift`); mixed corpus SHA-256: `a5e464955ccae8391d7826aa58c57c5c7bb45bcf38cca270fed6f6d83569f399`.
