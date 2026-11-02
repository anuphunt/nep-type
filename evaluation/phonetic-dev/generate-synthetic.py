#!/usr/bin/env python3
"""Synthetic development pairs from a locally supplied TSV; never holdout."""
import json, random, sys
rng = random.Random(389441)
reservoir = []
seen = 0
with open(sys.argv[1], encoding='utf-8') as source:
    for line in source:
        fields = line.rstrip('\n').split('\t')
        key = fields[0]
        if not (4 <= len(key) <= 18) or len(fields) < 2:
            continue
        positions = [(key.find(v), v) for v in ('aa', 'ii', 'uu') if key.find(v) >= 0]
        if not positions:
            continue
        index, _ = min(positions)
        alternative = key[:index] + key[index + 1:]
        if alternative == key:
            continue
        seen += 1
        row = {'roman': alternative, 'expected': [fields[1]], 'role': 'synthetic_nepali', 'original_key': key}
        if len(reservoir) < 250:
            reservoir.append(row)
        else:
            replacement = rng.randrange(seen)
            if replacement < 250:
                reservoir[replacement] = row
print(json.dumps({'description': 'Synthetic pairs derived from Aksharantar index; first lexically listed candidate, not reviewed, neither independent nor frequency-based. Vowel shrink may not match intended spelling.', 'source_rows_seen': seen, 'cases': reservoir}, ensure_ascii=False, indent=2))
