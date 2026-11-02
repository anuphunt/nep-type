# Android opt-in phonetic development check

This repeats the current Java service's index ordering and optional last-resort mapping on the previously inspected `evaluation/phonetic-dev/dev.json`. The 46 hand-authored, selectively labelled cases are unreviewed and are not a held-out or representative evaluation. English/name references are Roman originals, which the keyboard offers separately and are not expected in the index column. A label match is not proof that all other spellings are wrong or that a user would select the offered option.

Of 26 Nepali cases, an expected Devanagari spelling appeared in the index suggestions for 22 and with the opt-in fallback for 23. Two Nepali cases got a fallback: `patra` matched the reference, while `aakash` did not. Five of six English controls and three of ten lowercase name controls received a new approximate option; none of the four capitalized-name controls did. The Roman original remains independently available. This sample has no representative sentence context or actual host behavior. It is consistent with the earlier separate synthetic probe's warning about English noise, but it is not a fresh independent validation.

No ranking or phonetic rule was changed based on this sample. The UI source retains an approximation indicator on both the suggestion and the Use action and describes it for accessibility. The Android interface remains uncompiled and untested on a host. The next quality step is a larger Nepali-speaker-reviewed, intent-labelled development set with a separately frozen test set and actual usability testing; no frequency is inferred from index order.

From the project root:

```sh
python3 evaluation/android-all-dev/evaluate.py "$PWD" > /tmp/lekha-android-all-dev.json
```

The JSON records hashes for sources, fixture and indexes; its Java harness mirrors lookup but does not run Android UI or verify candidate selection in a real editor. Index provenance and unresolved licensing are documented in the main project.
