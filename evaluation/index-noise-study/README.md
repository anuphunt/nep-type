# Aksharantar structural noise diagnostic

`analyze.py` scans the existing sorted IndicCorp index, counts simple target-shape flags and measures whether each proposed individual filter would remove all accepted index matches for a previously used 59-row authored fixture. Run with Python 3:

```
python3 analyze.py /path/to/aksharantar-indiccorp-v1.tsv /path/to/alias-holdout-v1.json results.json
```

The indexed SHA-256 is recorded in results.json. Of 2,391,227 indexed pairs and 2,171,523 keys, five targets begin with a combining mark (examples in results); all five are the first lexical alternative. No targets in this index had a joiner at either boundary, lacked a Unicode letter, or exceeded 30 Unicode scalars. 188,305 keys have multiple indexed targets. These are counts of rows, not user exposure, frequency or spelling error rates. Counts omitted in JSON are zero.

The prior 59-row fixture had 18 indexed keys and 10 with an accepted indexed candidate; none of those accepted candidates were lost by any tested filter. It has been used previously, is small and is not an independent held-out evaluation. It cannot establish a filter's recall or linguistic correctness. The five visually suspicious entries appear malformed, but reviewers need linguistic and source-context evidence before treating the structural rule as safe. Many plausible-looking but wrong candidates will evade these tests. No filtering or production index change was made; lexical order is not a ranking or frequency. The untouched reserved probe was not used. A broader Nepali-speaker-reviewed set and separately frozen evaluation are needed to assess actual errors and filters.
