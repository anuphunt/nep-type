# Prior probe error triage

`analyze.py` classifies already-scored, selectively annotated Nepali tokens in `../frozen-comparison/baseline-pad.json`. Across 130 annotated Nepali tokens in that previously inspected synthetic probe, 94 matched the proposed top choice, 30 had a proposed spelling in the four shown choices plus original but not as top, and six lacked it in that visible list. This partitions the scorer's labels; it does not prove whether the underlying issue is ranking, spelling, morphology or an incomplete reference. A candidate present outside the displayed limit is counted as not visible.

The references were AI-authored, conversation-informed and not Nepali-speaker reviewed; the probe is already spent. It cannot establish population accuracy or be used as a fresh holdout. Results are in `results.json`.

From the project root: `python3 evaluation/error-taxonomy/analyze.py evaluation/frozen-comparison/baseline-pad.json`.
