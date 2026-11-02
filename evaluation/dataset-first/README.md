# Dataset-first experiment — not adopted

This is a comparison, not a decision to replace the current engine or make Aksharantar the sole source. The normal `build/NepType.app` uses the current engine. The old separately packaged test app was preserved during the rebrand at `/Users/anupdhakal/Desktop/apps/nepali-keyboard-archives/pre-neptype-2026-11-01/dataset-first-test.app`; its compiled interface predates the new branding. It is not an installed macOS input source. Do not distribute this historical build; Aksharantar commercial rights and source-chain review remain unresolved.

## Tested behavior

The candidate preserves existing explicit curated Nepali and English overrides. For other words, it preserves a word as Roman when it appears in the CMU English index and Google offers no Nepali candidate. Otherwise, if the Aksharantar index has exactly one match and the Roman word has at least three letters, it uses that match automatically. Multiple Aksharantar matches remain suggestions; no candidate is selected by alphabetic order or claimed model confidence. Other words keep the existing phonetic fallback. The original Roman word and undo remain available. Google and curated entries are retained: **this experiment is not a dataset-only engine**.

An exact one-to-one database match does not prove spelling or intended language. English dictionaries include names and other ambiguous words; the Google alias lookup also contains heuristic, ambiguous forms. The candidate is word-by-word and does not analyze surrounding sentence context.

## Results

| Measure | Current engine | Test candidate |
| --- | ---: | ---: |
| Phase 0 mixed development examples: English words preserved | 11/19 | 15/19 |
| Phase 0 mixed comparison examples: English words preserved | 7/15 | 13/15 |
| Same comparison examples: Nepali words top-1 | 22/28 | 22/28 |
| Same comparison examples: exact sentences | 2/10 | 4/10 |
| 59-word synthetic probe: top-1 intended spelling | 18/59 | 21/59 |
| 59-word synthetic probe: visible intended candidate | 45/59 | 45/59 |
| Aksharantar separate 4,101-word test split: top-1 exact Devanagari | 430/4,101 (10.5%) | 395/4,101 (9.6%) |

The 4,101-word test split is a word-level test with Devanagari expected for every item, including foreign and Indian names. It is not a mixed-language sentence benchmark, and the test's Roman keys do not occur in the indexed train split. Therefore gains from exact training-index matching are impossible on this split; the test chiefly exposes limitations of the fallback and English protection. There were 35 cases previously correct that became incorrect, and no cases in the other direction. For example, `muni` previously produced `मुनि` but is retained as `muni` by the test candidate. Counts use canonical Unicode normalization; examples are not a claim that Roman text is always wrong in a mixed sentence.

The 25 Phase 0 examples and 59-word probe are small, synthetic/provisional, already reviewed and not independent blind tests. The 4,101-word test is broader and split from train, but is not a representative mixed-typing sample. Human review and new consented mixed-language examples are needed before making a product-quality claim.

The target sentence changes from `आज मेरो फोने को बत्तेर्य लितेरल्ल्य देअद भैसकेको थियो` to `आज मेरो phone को battery literally dead भैसकेको थियो`: English improves, but the intended `भइसकेको` is still only an alternative to the default `भैसकेको`. `farkechhan` uses a unique Aksharantar match to produce `फर्केछन्`; a single match can still be wrong.

## Verification and performance

14 Swift unit tests passed against the candidate, and the separately packaged app passed 25 UI checks, including automatic dataset selection, original-text recovery, undo, switching, candidate labels and wrapping. Three local app runs on Apple M4 Max / macOS 26.6.2 reached the first window from main entry in 126.189–142.661 ms with warm caches. One optimized 100,000-lookup microbenchmark measured p50 53.042 µs, p95 69.750 µs and p99 82.625 µs; the first lookup including lazy English-index initialization took 28.112 ms. Those are not end-to-end input latency measurements.

The full mixed-case before/after result JSON and aggregate official test results are beside this file. `Transliterator.before.swift` and `Transliterator.candidate.swift` are snapshots, not active app sources. The underlying active source remains `Sources/NepaliCore/Transliterator.swift`. Reproduction uses the same bundled Google and Aksharantar TSV indexes with `NEPTYPE_ALIAS_INDEX` and `NEPTYPE_AKSHARANTAR_INDEX` set to their paths and compiles either snapshot with `Sources/NepaliCore/Composer.swift`, `GeneratedIndexes.swift`, `GeneratedAliasIndex.swift` and `evaluation/phase0/main.swift`. The official test requires the pinned original `nep.zip` and its `nep_test.json`; see the Phase 1 report for the archive SHA-256 and source.

**Recommendation:** do not make the dataset the sole source of truth based on this experiment. The training index has no exact Roman-key overlap with the 4,101-word test split, and English preservation introduces false negatives for ambiguous names. Evaluate a larger, speaker-reviewed mixed-language set and consider context/ranking or other models before changing the normal app.
