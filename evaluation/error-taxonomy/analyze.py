#!/usr/bin/env python3
"""Classify scored, selective Nepali-token errors in a saved probe result.

This uses the evaluator's own labels; it does not adjudicate spelling, infer
cause, or treat a previously scored fixture as a fresh holdout.
"""
import collections
import json
import sys

result = json.load(open(sys.argv[1], encoding="utf-8"))
counts = collections.defaultdict(collections.Counter)
for case in result["cases"]:
    for token in case["tokens"]:
        if token["role"] != "nepali":
            continue
        category = counts[case["category"]]
        category["total"] += 1
        if token["correct"]:
            category["top_match"] += 1
        elif token["candidate_available"]:
            category["expected_visible_but_not_top"] += 1
        else:
            category["expected_not_visible"] += 1
print(json.dumps({"method":"Selective unreviewed annotations; visible means first four candidates plus original. These categories do not identify root cause.","categories":counts}, ensure_ascii=False, indent=2, sort_keys=True))
