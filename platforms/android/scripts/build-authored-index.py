#!/usr/bin/env python3
"""Generate or check a byte-sorted Android index from NepType's authored JSON."""
import argparse
import json
import re
from pathlib import Path

here = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=here / '../../data/sources/nepali-authored-v1.json')
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
source = json.loads(args.source.read_text(encoding='utf-8'))
rows = []
for key in sorted(source):
    values = source[key]
    if not re.fullmatch(r'[a-z]+', key) or not isinstance(values, list) or not values:
        raise ValueError('Invalid key or values: ' + key)
    if any(not isinstance(v, str) or not v or any(c in v for c in '\t\r\n') for v in values):
        raise ValueError('Invalid candidate: ' + key)
    rows.append(key + '\t' + '\t'.join(values) + '\n')
result = ''.join(rows).encode('utf-8')
dest = here / 'app/src/main/assets/nepali-authored-v1.tsv'
if args.check:
    if dest.read_bytes() != result:
        raise SystemExit('Authored index is stale; rerun scripts/build-authored-index.py')
    print(f'PASS: authored index matches {len(rows)} source entries')
else:
    dest.write_bytes(result)
    print(f'Generated {len(rows)} authored entries: {dest}')
