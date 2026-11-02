# Third-party notices

NepType's [MIT license](LICENSE) covers project-authored code, documentation,
artwork, and the authored vocabulary in `data/sources/nepali-authored-v1.json`.
Third-party material and data derived from it retain their own terms. MIT does
not replace those terms or grant rights that the upstream contributors do not own.

These notices also apply to copies of the resources in platform folders,
generated source files, and packaged apps. Preserve the relevant notices when
redistributing source or binaries. Include `LICENSE`, this file, and the applicable
source notices with a distribution; retain the full CMU license text.

## CMU Pronouncing Dictionary

Copyright (C) 1993–2015 Carnegie Mellon University. All rights reserved.

The pinned source is `data/sources/cmudict.dict`. Its English word forms are
embedded in `GeneratedIndexes.swift` files by `scripts/build-indexes.py` and
copied into the portable and platform cores. The project code around those
words is MIT-licensed; the CMU-derived data retains the
[CMU redistribution conditions and disclaimer](data/sources/CMUDICT-LICENSE.txt).
That notice must accompany source and binary redistributions.

## Google Nepali pronunciation lexicon

Copyright 2018 Google Inc. Licensed under
[Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

The pinned source is `data/sources/google-ne-lexicon.tsv`, from
[Google language-resources, revision a90601024f07ab7e96c911243324e0adeb16da96](https://github.com/google/language-resources/blob/a90601024f07ab7e96c911243324e0adeb16da96/ne/data/lexicon.tsv).
`data/compiled/google-ne-aliases.tsv` and its platform copies are adaptations:
NepType selects Devanagari spelling and phonemic transcription rows, generates
approximate Roman aliases using project-authored rules with bounded variants,
and sorts and groups the resulting pairs.

Retain the [attribution and modification notice](data/sources/GOOGLE-NE-ATTRIBUTION.txt)
and the license link. Google does not endorse this adaptation.

## Aksharantar Nepali training data

Source: AI4Bharat Aksharantar (Madhani et al.), revision
`e418c1fc928d9f5393af33268472cf20c1891be8`.
See the [pinned dataset card](https://huggingface.co/datasets/ai4bharat/Aksharantar/blob/e418c1fc928d9f5393af33268472cf20c1891be8/README.md)
and [paper](https://arxiv.org/abs/2205.03018).

`data/compiled/aksharantar-indiccorp-v1.tsv` and its platform copies contain
filtered, sorted, deduplicated IndicCorp-labeled training pairs. Scores were
discarded; ordering is not a frequency estimate. Exact transformations, counts,
and hashes are recorded in the
[manifest](data/compiled/aksharantar-indiccorp-v1.manifest.json).

This resource is **not covered by NepType's MIT license**. The existing project
audit records that upstream's CC0 statement applies to packaging of mined data,
while underlying text ownership and the exact source chain remain unresolved.
Making NepType open source or charging no fee does not resolve that question.
Redistribution rights, including commercial redistribution, still need to be
clarified before treating this index as freely redistributable.

Retain the [source notice](data/sources/AKSHARANTAR-ATTRIBUTION.txt).
See the [rights audit](evaluation/phase1/REPORT.md#aksharantar-archive-and-source-rights)
for the evidence and limits of that assessment. The current local builds include
this index; the repository's MIT license does not represent clearance for it.
