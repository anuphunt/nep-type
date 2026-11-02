#!/usr/bin/env python3
"""Reproduce a development-only, index-versus-opt-in fallback comparison."""
import argparse
import hashlib
import json
import subprocess
import tempfile
from collections import defaultdict
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('root', type=Path)
parser.add_argument('--jdk', type=Path, default=Path('/opt/homebrew/opt/openjdk/bin'))
args = parser.parse_args()
root = args.root.resolve()
core = root / 'platforms/android/app/src/main/java/app/neptype/keyboard/core'
fixture = root / 'evaluation/phonetic-dev/dev.json'
indexes = [root / 'platforms/android/app/src/main/assets/nepali-authored-v1.tsv',
           root / 'data/compiled/aksharantar-indiccorp-v1.tsv', root / 'data/compiled/google-ne-aliases.tsv']
files = [fixture, *(core / (name + '.java') for name in ('CandidateMerger', 'SortedCandidateIndex', 'PhoneticCandidates')),
         root / 'evaluation/platform-compare/ServiceLookup.java', *indexes]
hashes = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
cases = json.loads(fixture.read_text())['cases']
with tempfile.TemporaryDirectory(prefix='neptype-android-all-eval-') as tmp:
    subprocess.run([str(args.jdk / 'javac'), '--release', '8', '-d', tmp, *map(str, files[1:5])], check=True)
    command = [str(args.jdk / 'java'), '-cp', tmp, 'ServiceLookup', *map(str, indexes)]
    source = ''.join(case['roman'] + '\n' for case in cases)
    runs = [subprocess.run(command + [mode], input=source, text=True, capture_output=True, check=True).stdout.splitlines()
            for mode in ('baseline', 'candidate')]
    if any(len(run) != len(cases) for run in runs):
        raise RuntimeError('Unexpected lookup output count')
    stats = defaultdict(lambda: {'total': 0, 'expected_in_index': 0, 'expected_in_all': 0, 'added_approx': 0})
    rows = []
    for case, before, after in zip(cases, *runs):
        before = before.split('\t') if before else []
        after = after.split('\t') if after else []
        group = stats[case['role']]; group['total'] += 1
        group['expected_in_index'] += int(any(x in before for x in case['expected']))
        group['expected_in_all'] += int(any(x in after for x in case['expected']))
        group['added_approx'] += int(before != after)
        rows.append({'input': case['roman'], 'role': case['role'], 'expected': case['expected'], 'index': before, 'all': after})
    print(json.dumps({'note': 'Previously inspected, unreviewed development cases; not held out or representative. Original is separately available.',
                      'sha256': hashes, 'stats': stats, 'cases': rows}, ensure_ascii=False, indent=2))
