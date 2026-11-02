# Vowel-length lookup development experiment — rejected

This is an isolated offline development experiment. It does not edit or replace the NepType engine, and no input source was installed. It explores a bounded single `a`/`aa`, `i`/`ii`, or `u`/`uu` Roman-key variant against the existing Aksharantar and pronunciation-derived Google alias indexes. At most four alternative keys and two suggestions are considered. Exact/base choices retain priority; the original remains available and automatic output never changes. The guard excludes known English words, uppercase/non-ASCII, long inputs, and inputs with two or more exact mined candidates. Candidate order is source order, not a claimed word frequency.

## Development findings

- On 26 manually written Nepali development tokens, expected spelling was visible for 23 before and after. There were **no new suggestions and no observed improvement**. Six English, four capitalized-name and ten lowercase-name controls kept their reference/original available; none received a new suggestion in this tiny set. These references are not reviewed by a Nepali speaker and alternatives may be valid.
- A seeded 250-case sample was constructed by shortening a double vowel in a key from the *same Aksharantar index queried by the experiment*. Visible matches to that row's first lexical candidate increased from 3/250 to 230/250, with 227 of 238 newly added candidates equal to that mechanical reference. This is a circular self-consistency check, **not** accuracy or precision: keys were selected specifically to have such a source mapping, alternative Roman forms may not mean the same word, the source candidate may be noisy, and lexical first does not mean most common. It does not establish benefit to actual typing.
- In one warmed Mac process on that synthetic sample, 1,200 lookups per configuration measured p50/p95 0.1052/0.1328 ms baseline and 0.1529/0.1935 ms expanded. This small sequential hot-cache microbenchmark includes candidate building, is not device/host typing latency, and cannot support a general performance claim.

**Recommendation: reject this candidate for integration.** The realistic development set showed no added coverage, while the impressive same-index score is circular. Further evaluation would need genuinely independent, Nepali-speaker-reviewed aliases, plausible intent/English/name controls, source-quality review and a separately frozen test set. Do not tune on any previously frozen evaluation. This experiment does not demonstrate any automatic transcription or morphology improvement.

## Reproduce

Run from this directory, using the source indexes already in the parent project:

```sh
swiftc -O -module-cache-path /tmp/neptype-phonetic-dev-cache Transliterator.swift Composer.swift GeneratedIndexes.swift GeneratedAliasIndex.swift main.swift -o /tmp/neptype-phonetic-dev
export NEPTYPE_ALIAS_INDEX=/absolute/path/to/google-ne-aliases.tsv
export NEPTYPE_AKSHARANTAR_INDEX=/absolute/path/to/aksharantar-indiccorp-v1.tsv
/tmp/neptype-phonetic-dev dev.json > results-google.json
python3 generate-synthetic.py "$NEPTYPE_AKSHARANTAR_INDEX" > synthetic-index-dev.json
/tmp/neptype-phonetic-dev synthetic-index-dev.json --bench > synthetic-results.json
```

The timing line goes to standard error. `source-hashes.txt` records the source and index hashes used. The fixture, renderer and index sources in this directory are developer research artifacts and carry the main project's existing attribution and unresolved Aksharantar commercial review. The hand-written examples and same-index sample are development data, not independent held-out tests. Results depend on these specific index versions.
