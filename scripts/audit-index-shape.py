#!/usr/bin/env python3
"""Audit the two shipped TSVs against the engine's structural limits.

This validates shape, not source rights, linguistic quality or trusted content.
"""
import json
import sys

def audit(path):
    rows = 0; max_bytes = 0; max_candidates = 0; max_scalars = 0; previous = None
    with open(path, "rb") as source:
        for line in source:
            rows += 1
            if not line.endswith(b"\n") or len(line) - 1 > 4096:
                raise ValueError(f"{path}: malformed/oversized row {rows}")
            fields = line[:-1].decode("utf-8").split("\t")
            key, values = fields[0], fields[1:]
            if not key or not all("a" <= c <= "z" for c in key) or not values or len(values) > 64:
                raise ValueError(f"{path}: malformed key/candidate count at row {rows}")
            if previous is not None and key <= previous:
                raise ValueError(f"{path}: non-increasing key at row {rows}")
            previous = key
            for value in values:
                if not value or len(value) > 60 or not all(0x0900 <= ord(c) <= 0x097F or ord(c) in (0x200C, 0x200D) for c in value):
                    raise ValueError(f"{path}: malformed candidate at row {rows}")
                max_scalars = max(max_scalars, len(value))
            max_bytes = max(max_bytes, len(line) - 1)
            max_candidates = max(max_candidates, len(values))
    return {"path":path, "rows":rows, "max_row_bytes_excluding_newline":max_bytes, "max_candidates":max_candidates, "max_candidate_scalars":max_scalars}

print(json.dumps([audit(path) for path in sys.argv[1:]], ensure_ascii=False, indent=2))
