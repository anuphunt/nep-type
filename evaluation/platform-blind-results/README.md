# Frozen cross-platform comparison — 30 October 2026

This 55-case probe was authored separately from the Android implementation and frozen before the evaluator or either version was run. It is AI-authored, synthetic, conversation-informed and not reviewed by a Nepali speaker; it is not a representative or independent user-population accuracy estimate. Annotations are selective. The development and fixture authors did not exchange examples before scoring. `pre-evaluation-hashes.txt` records the fixture, evaluator, Java implementations, Swift source and index bytes before the run; `corpus.json`, `swift.json`, and `comparison.json` contain the complete evidence. No post-probe tuning is represented here.

## What was compared

The existing Swift standalone pad uses context-ranked automatic output and up to four visible alternatives plus original. The Android baseline and candidate **both keep Roman text as the default**; their service-style lookup was mirrored in a local pure-Java harness. The candidate adds a labeled, optional phonetic suggestion only when the existing indexes provide no choices. Android's SDK, UI and host were not exercised. Sentence-level Android counts assume raw input with no user selections; they are not an equivalent measure of automatic transliteration quality. Swift literal annotations may use containment rather than positional checks; Android literal preservation assumes raw default. Neither path tests field context, platform lifecycle, undo or privacy in a real app.

| Category | Cases | Swift sentence exact | Android unchanged-input exact |
|---|---:|---:|---:|
| English | 11 | 11 | 11 |
| Nepali | 11 | 3 | 0 |
| Mixed | 11 | 2 | 0 |
| Ambiguity | 11 | 6 | 3 |
| Literal | 11 | 9 | 8 |

For 122 selectively annotated Nepali token occurrences, the expected spelling was available among Android's four service-style options plus original for **111 baseline and 115 candidate** occurrences. The gain comprised three occurrences in the Nepali category and one in the ambiguity category; these are occurrence counts, not distinct vocabulary or verified user outcomes. Swift offered an expected option for 115/122, and its automatic top choice matched 89/122. Candidate fallback also changed the optional suggestion list for **61 of 97 annotated English occurrences**. The Roman default stayed unchanged, but the extra approximate suggestions can be distracting or misleading. All 11 annotated literal spans passed the Swift token/containment check and were unchanged under the Android raw-input assumption.

The evidence supports only a narrow availability gain with considerable English suggestion noise. It does not establish that a user will find, select or benefit from the right spelling, and does not justify automatic conversion. English names, unreviewed spelling alternatives, context and field constraints need additional review. The result should be used once for this decision, not reused as an untouched holdout for subsequent tuning.
