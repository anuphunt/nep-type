# Rejected Android phonetic fallback experiment

This source snapshot is **not active in the Android keyboard**. It evaluated a lowercase ASCII last-resort suggestion based on the shared Swift phonetic mapping, shown only when all index sources returned no suggestions. Roman input remained the default and applying a candidate required explicit selection. The uncompiled Android service prototype labeled the extra option with `≈` and an accessibility description. The source hashes in `SOURCE_HASHES.sha256` match the frozen candidate before the evaluation; `NepTypeKeyboardService.candidate.java` is a historical snapshot, not a build target.

A separate author-frozen synthetic probe found four more expected Nepali candidates, but candidate lists changed for 61 of 97 annotated English tokens. Such false-choice noise is too broad without evidence that users benefit. The candidate was therefore rejected and its active service integration removed. The fixture is synthetic, selective, unreviewed and not a representative accuracy measure. The parent task records the full evaluation and methodology. No automatic behavior was changed, and the current Android service retains indexed suggestions and the Roman default.

The mapping matches Swift's `Transliterator.phonetic` for 5,010 deterministic lowercase ASCII inputs, as verified before rejection. The comparison is implementation parity, not a language-accuracy claim. A single hot Mac/JDK run of 10,000 calls measured p50 0.0011 ms / p95 0.0023 ms; this excludes Android, cold start, index lookup, UI and keystroke delivery.

## Reproduce from the project root

```sh
NEPTYPE_ROOT="$PWD" JDK_BIN=/opt/homebrew/opt/openjdk/bin \
  platforms/android/experiments/phonetic-fallback/run-phonetic-parity.sh
```

This builds the retained historical Java candidate and current Swift phonetic function into a temporary directory, and compares deterministic outputs. The exact rejected service was never built or tested on an Android SDK/device. No input source was installed.
