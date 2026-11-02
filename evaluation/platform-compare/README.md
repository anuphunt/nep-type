# Cross-platform frozen comparison

This harness compares a frozen, selectively annotated corpus against the existing Swift standalone engine and two Android Java lookup versions. It never builds Android, enables an input source, exercises an OS text host, or records user typing. Use only with artificial, non-sensitive fixtures.

Before use, freeze the fixture and both implementations. `run.sh` hashes fixture, evaluator, sources and indexes before invoking either version; it refuses to overwrite its output directory. It builds temporary local Swift and Java processes and runs each comparison once. It assumes `ServiceLookup.java` has been reviewed against both Android service implementations; the helper mirrors authored → mined → Google (up to four), with candidate-only `PhoneticCandidates.lastResort` and a separate pinned original. If service behavior changes, update and review the mirror **before** examining a fresh heldout fixture.

```sh
./run.sh /path/to/neptype /path/to/candidate/android /path/to/frozen.json /path/to/jdk/bin /path/to/new-output-directory
```

The Swift evaluator reports full-text contextual pad top choices, its first four suggestions plus original, and strict sentence matches. Android scores original Roman as the default; its baseline/candidate lookup values are optional, isolated-token suggestions. Sentence-level Android score assumes unchanged input with no manual selections; it is not real typing or a decision accuracy metric. Literal counts in the Swift evaluator can use containment rather than positional preservation; Android literal counts assume raw input. Annotation is selective. Tokenized names, context, UI timing, field traits, focus, clipboard, UTF-16 host ownership, loss and platform accessibility are not tested.

The two implementations have different behavior and candidate selection requirements. Candidate availability is not proof users choose correctly, nor are strict references authoritative when not speaker-reviewed. Data-driven, synthetic or conversation-informed examples are not a representative user sample. The large dataset's licensing and provenance remain as recorded in the parent project.

## Recreate the rejected fallback for audit

The active Android service was restored after the comparison. Its exact rejected service and `PhoneticCandidates.java` are preserved in `platforms/android/experiments/phonetic-fallback/`, with hashes. To repeat on a trusted local copy without changing the project, copy `platforms/android` to a **new empty temporary directory**, then copy the historical service snapshot to `app/src/main/java/app/neptype/keyboard/NepTypeKeyboardService.java` and historical `PhoneticCandidates.java` to `app/src/main/java/app/neptype/keyboard/core/PhoneticCandidates.java` within that temporary copy. Pass that copy as `CANDIDATE_ANDROID_DIR`. Do not replace the active service. This only reproduces the spent comparison; use a newly authored frozen fixture for any later decision.
