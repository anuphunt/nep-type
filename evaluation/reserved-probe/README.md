# Frozen synthetic Nepali spelling and control probe

`corpus.json` contains 100 distinct Roman inputs: 20 daily vocabulary, 20 action words, 20 inflected forms, 20 paired Roman spelling variants, ten English controls and ten name controls. Each case specifies `id`, `category`, `role`, `roman`, and one or more `acceptable` outputs. For the controls, the proposed output is the original spelling. The paired variants are deliberate comparisons, not independent observations.

This fixture was written separately from the development agents and frozen without executing NepType or seeing its outputs. It is AI-authored, synthetic, conversation-informed and unreviewed by Nepali speakers. It is not a representative independent sample or accuracy benchmark. Roman spelling, word sense, name intent and Devanagari conventions can be ambiguous; some acceptable forms may be missing, and some labels may require correction. Do not tune candidate implementation against these cases and continue calling them untouched.

For Nepali cases, report top-choice match, expected reading among actually visible candidates, expected reading anywhere in the candidate list, and original availability separately. For English and name controls report exact original top-choice preservation and original availability. Report by category and do not count offering the original as evidence that a keyboard chose the intended language. Note any candidate-count limits and ordering. No result can establish native host behavior, typing latency or user editing costs.

`generate.py` generates the references without invoking the engine. SHA-256 of `corpus.json` before evaluation:

`77b99b6f26d4bc1e3f523a195a1bda14e18819da858fa4a88f274dc1c768d11c`

## Status

Reserved and **not scored** in this task. The phonetic and morphology proposals were rejected using development evidence before this fixture was opened by those authors or run against either engine. Keep it untouched for a future independently frozen candidate; it remains synthetic, conversation-informed and unreviewed, not a representative user sample. `pre-evaluation-hashes.txt` records the then-current baseline and fixture/scorer bytes, not a completed comparison.
