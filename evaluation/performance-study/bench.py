#!/usr/bin/env python3
"""Mac local process/IPC diagnostics; does not install a keyboard or invoke a UI."""
import argparse
import json
import math
import os
import re
import statistics
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--executable', required=True)
parser.add_argument('--alias-index', required=True)
parser.add_argument('--mined-index', required=True)
parser.add_argument('--build-type', choices=('debug', 'release', 'other'), default='debug')
parser.add_argument('--runs', type=int, default=10)
parser.add_argument('--rounds', type=int, default=20)
args = parser.parse_args()
words = ['namaste', 'mero', 'pani', 'bhaisakeko', 'office', 'football', 'janchu', 'bato', 'malai', 'ghar']
if args.runs < 2 or args.rounds < 1:
    parser.error('runs must be >= 2 and rounds >= 1')

def p(values, fraction):
    return sorted(values)[max(0, math.ceil(len(values)*fraction)-1)]

def summarize(values):
    return {'n': len(values), 'median': statistics.median(values), 'p95': p(values, .95), 'min': min(values), 'max': max(values)}

def scenario(indexed):
    fresh, first, lookups, rss, footprint, first_candidate = [], [], [], [], [], []
    for run in range(args.runs):
        env = dict(os.environ)
        # A nonexistent explicit path prevents accidental fallback to bundled data.
        env['NEPTYPE_ALIAS_INDEX'] = args.alias_index if indexed else '/tmp/neptype-benchmark-no-such-alias-index'
        env['NEPTYPE_AKSHARANTAR_INDEX'] = args.mined_index if indexed else '/tmp/neptype-benchmark-no-such-mined-index'
        start = time.perf_counter_ns()
        proc = subprocess.Popen(['/usr/bin/time', '-l', args.executable], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True, bufsize=1)
        def request(op, **extra):
            payload = {'id': 'bench', 'op': op, **extra}
            t0 = time.perf_counter_ns()
            proc.stdin.write(json.dumps(payload, ensure_ascii=False)+'\n')
            proc.stdin.flush()
            result = proc.stdout.readline()
            if not result:
                raise RuntimeError('engine ended before response')
            parsed = json.loads(result)
            if not parsed.get('ok'):
                raise RuntimeError('engine rejected '+op+': '+str(parsed))
            return (time.perf_counter_ns()-t0)/1e6, parsed
        _, created = request('create')
        fresh.append((time.perf_counter_ns()-start)/1e6)
        ms, response = request('append', text='bhaisakeko')
        first.append(ms)
        first_candidate.append('भइसकेको' in response['state']['candidates'])
        request('cancel')
        for word in words * args.rounds:
            ms, _ = request('append', text=word)
            lookups.append(ms)
            request('cancel')
        proc.stdin.close()
        tail = proc.stderr.read()
        code = proc.wait(timeout=10)
        if code:
            raise RuntimeError('engine/time exited '+str(code)+': '+tail)
        match = re.search(r'^\s*(\d+)\s+maximum resident set size\s*$', tail, re.M)
        if not match:
            raise RuntimeError('maximum resident set unavailable: '+tail)
        rss.append(int(match.group(1)))
        match = re.search(r'^\s*(\d+)\s+peak memory footprint\s*$', tail, re.M)
        if match:
            footprint.append(int(match.group(1)))
    return {'fresh_process_to_empty_session_ms': summarize(fresh), 'first_lookup_ipc_ms': summarize(first), 'later_lookup_ipc_ms': summarize(lookups), 'max_rss_bytes': summarize(rss), 'peak_footprint_bytes': summarize(footprint) if footprint else None, 'first_word_includes_mined_suggestion': first_candidate}

result = {
    'method': 'Fresh local process per run; OS file cache not cleared. /usr/bin/time -l wraps a JSON-lines engine; latency includes pipes, JSON and controller state serialization. Later lookups repeat ten words. No UI or actual keyboard host.',
    'build_type': args.build_type,
    'runs_per_scenario': args.runs, 'rounds_per_run': args.rounds, 'words': words,
    'index_bytes': {'google': os.path.getsize(args.alias_index), 'aksharantar': os.path.getsize(args.mined_index)},
    'scenarios': {'indexes_present': scenario(True), 'explicit_missing_paths': scenario(False)}
}
print(json.dumps(result, indent=2, ensure_ascii=False))
