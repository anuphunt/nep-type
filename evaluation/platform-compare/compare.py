#!/usr/bin/env python3
"""Compare precomputed Swift scores with baseline and candidate Java options.

Input fixture must be frozen before use. This never invokes Android APIs or a
host. Android keeps the original as default; candidate values are optional.
"""
import collections
import json
import subprocess
import sys
import unicodedata

fixture, swift_path, java, baseline_classpath, candidate_classpath, authored, mined, google = sys.argv[1:]
data = json.load(open(fixture, encoding="utf-8"))
swift = json.load(open(swift_path, encoding="utf-8"))
assert len(data["cases"]) == len(swift["cases"])
items = []
for case, scored in zip(data["cases"], swift["cases"]):
    assert case["id"] == scored["id"] and case["category"] == scored["category"]
    assert len(case["annotations"]) == len(scored["tokens"])
    for annotation, token in zip(case["annotations"], scored["tokens"]):
        assert annotation["token"] == token["input"] and annotation["role"] == token["role"]
        if annotation["role"] != "literal":
            assert "\n" not in annotation["token"] and "\r" not in annotation["token"]
            items.append((case["id"], case["category"], annotation, token))
request = "".join(annotation["token"] + "\n" for _, _, annotation, _ in items)
def lookup(classpath, mode):
    process = subprocess.run([java, "-cp", classpath, "ServiceLookup", authored, mined, google, mode],
                             input=request, text=True, capture_output=True, check=True)
    lines = process.stdout.splitlines()
    assert len(lines) == len(items), (mode, len(lines), len(items), process.stderr)
    return [line.split("\t") if line else [] for line in lines]
baseline, candidate = lookup(baseline_classpath, "baseline"), lookup(candidate_classpath, "candidate")
def norm(value): return unicodedata.normalize("NFC", value)
summary = collections.defaultdict(lambda: collections.Counter())
rows = []
for (case_id, category, annotation, swift_token), b, c in zip(items, baseline, candidate):
    original = annotation["token"]
    expected = {norm(value) for value in annotation["acceptable"]}
    raw_correct = norm(original) in expected
    b_available = any(norm(value) in expected for value in [original] + b)
    c_available = any(norm(value) in expected for value in [original] + c)
    counters = summary[category]
    prefix = annotation["role"] + "_"
    counters[prefix + "total"] += 1
    counters[prefix + "swift_top"] += bool(swift_token["correct"])
    counters[prefix + "swift_available"] += bool(swift_token["candidate_available"])
    counters[prefix + "android_raw_default"] += raw_correct
    counters[prefix + "android_baseline_available"] += b_available
    counters[prefix + "android_candidate_available"] += c_available
    counters[prefix + "candidate_list_changed"] += b != c
    rows.append({"case":case_id,"category":category,"token":original,"role":annotation["role"],
                 "expected":annotation["acceptable"],"swift_top":swift_token["actual"],
                 "swift_top_correct":swift_token["correct"],"swift_candidate_available":swift_token["candidate_available"],
                 "android_raw_default_correct":raw_correct,"android_baseline_options":b,
                 "android_candidate_options":c,"android_baseline_available":b_available,
                 "android_candidate_available":c_available})
sentence_summary = collections.defaultdict(lambda: collections.Counter())
for case, scored in zip(data["cases"], swift["cases"]):
    counts=sentence_summary[case["category"]]
    counts["total"] += 1
    counts["swift_exact"] += bool(scored["exact"])
    counts["android_raw_exact"] += norm(case["input"]) in {norm(s) for s in case["expected"]}
    for annotation, token in zip(case["annotations"], scored["tokens"]):
        if annotation["role"] == "literal":
            counters=summary[case["category"]]
            counters["literal_total"] += 1
            counters["literal_swift_preserved"] += bool(token["correct"])
            counters["literal_android_raw_preserved"] += norm(annotation["token"]) in {norm(s) for s in annotation["acceptable"]}
print(json.dumps({"fixture_version":data["version"],"sentences":sentence_summary,
                 "annotated_tokens":summary,"cases":rows,
                 "method":"Swift contextual pad top/four choices; Android raw default and isolated-token service-style four index options plus original, with optional phonetic fallback; no selection or native host. Swift literal checks may use output containment; Android literal preservation assumes raw default. Selective annotations, unreviewed synthetic references."}, ensure_ascii=False, indent=2, sort_keys=True))
