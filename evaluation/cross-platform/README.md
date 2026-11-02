# Cross-platform candidate probe

This eight-word hand-picked fixture compares candidate availability in the Swift session harness and the Android Java index layers. It is a regression aid, not an accuracy or ranking benchmark, and does not exercise either operating system's keyboard. Android combines authored, Aksharantar and Google candidates; it does not use Swift's contextual ranking. Roman original handling is exercised separately by each platform's tests.

The first comparison exposed a missing curated `football → फुटबल` option on Android. The current recorded result follows integration of the complete project-authored index. All eight example spellings are available in both probe outputs; this small deliberately selected set cannot establish broader coverage.

To repeat on the development Mac after building `portable-core` and setting `JDK_BIN` to an installed JDK's `bin` directory:

```sh
mkdir -p /tmp/lekha-cross-probe
"$JDK_BIN/javac" -d /tmp/lekha-cross-probe platforms/android/app/src/main/java/app/lekha/keyboard/core/SortedCandidateIndex.java evaluation/cross-platform/CandidateProbe.java
PATH="$JDK_BIN:$PATH" python3 evaluation/cross-platform/compare.py /path/to/lekha-conformance /tmp/lekha-cross-probe data/compiled/aksharantar-indiccorp-v1.tsv data/compiled/google-ne-aliases.tsv platforms/android/app/src/main/assets/nepali-authored-v1.tsv
```

Run from the Lekha project root. The dataset licensing status remains as described in the main plan.

`evaluate_fixture.py` accepts the same five arguments plus a JSON fixture containing `[roman, [acceptable spellings]]` pairs. Using the existing `evaluation/phase1/alias-holdout-v1.json` fixture returned 45/59 for the Swift candidate list and 41/59 for the Android top four. This earlier manually curated Google-alias holdout is not independent of the current curated or Aksharantar sources. It measures only whether an expected string appears in the candidate lists; it does not measure ranking quality, context, key events, or typing accuracy. The detailed results are in `alias-fixture-results.json`.

`evaluate_mixed_candidates.py` takes the same arguments and a phase-2 annotated mixed-sentence JSON fixture. On the 20 previously inspected synthetic sentences, isolated-token options contained an acceptable spelling for 41/43 annotated Nepali tokens in each engine; all 34 English tokens included their original input as an option. This does not establish that either engine automatically chooses the right option. Context was deliberately excluded, and these results are not independent accuracy measurements. Details: `mixed-candidate-results.json`.
