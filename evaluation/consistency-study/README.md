# Cross-platform candidate consistency diagnostic

This is an offline, host-independent comparison between the current Swift `InputSession` and the Android service's Java index lookup/merge logic. It is not a keyboard, Android build, real typing test, or accuracy benchmark. The Swift session uses isolated words with no prior context; the Android lookup returns up to four suggestions, and its user interface separately preserves the original Roman text as the default until an explicit selection. The test-only `ServiceLookup.java` uses the same `SortedCandidateIndex` and `CandidateMerger` classes as the Android service.

## Observations on the development Mac

- All **259/259** project-authored entries exposed at least one authored spelling and all authored spellings in both lists; Swift also exposed the original for 259/259. The first non-Roman choice agreed for 259/259. This is circular by construction because both implementations consume this authored source; it tests synchronization, not coverage or accuracy.
- A deterministic reservoir sample of **400** rows from the bundled Aksharantar index found the first indexed reading somewhere in the Swift list and in Android's first four suggestions for 400/400; Swift exposed the original in 400/400. The first indexed reading is lexically stored data, not ground truth, frequency or proof of a correct spelling.
- On that deliberately index-derived sample, Swift's first choice was the original Roman text for **3/400** inputs; Android's prototype retains Roman by default for all inputs until the user selects. This is a consequential design difference, not evidence that 397 conversions are wrong or a representative rate. The samples can contain names, OCR noise and unusual forms, and neither adapter was evaluated in a native host. Compare actual language intent on independently collected and speaker-reviewed data before changing defaults.

The full authored diagnostic is `results.json`; `sampled-index.json` and `sampled-results.json` contain the fixed-seed sample and outputs. The sample is derived from the user-authorized index; source/redistribution rights remain unresolved before distribution. These inputs were inspected and are not held out.

## Repeat locally

Copy this folder to `evaluation/consistency-study`, then from the Lekha project root run:

```sh
JDK_BIN=/path/to/installed/jdk/bin ./evaluation/consistency-study/run.sh
```

The script builds the portable Swift test harness and the two pure Java Android core classes into a unique temporary directory, generates a fixed-seed 400-row sample, compares the 259 authored entries and sample, checks authored-candidate/original invariants and explicit missing-index behavior, and removes its temporary directory. The missing-index test checks that Swift retains its Roman candidate and the Java index layer returns no alternatives; Android's separate original control is not exercised. It uses the project's indexes and does not install or enable an input source. SwiftPM sandboxing is disabled for this local test to avoid nested-sandbox failure in the managed environment. Android's service is not compiled by this script, and it does not validate UI, host ownership, actual selection, context ranking or latency. Results will legitimately change if data or source changes; investigate invariant failures rather than treating the counts as quality targets.

The current cross-platform differences are architectural: Swift has curated/context scoring, phonetic fallback and some automatic conversion; Android performs exact index lookup with explicit selection. A common fixture and common candidate contract can expose drift, but sharing an engine, native bridge and safe platform lifecycles must be designed and tested before claiming behavioral parity. Never infer word frequency from candidate order or model confidence.
