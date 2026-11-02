#!/usr/bin/env python3
"""Probe actual Swift engine candidate through C++ adapter; no OS integration."""
import json
import subprocess
import sys

engine, adapter_test = sys.argv[1:]
requests = [{'id': 'windows-test', 'op': 'create'},
            {'id': 'windows-test', 'op': 'append', 'text': 'namaste'}]
result = subprocess.run([engine], input=''.join(json.dumps(x) + '\n' for x in requests),
                        text=True, capture_output=True, check=True, timeout=10)
responses = [json.loads(x) for x in result.stdout.splitlines()]
assert len(responses) == 2 and responses[1]['accepted']
options = responses[1]['state']['candidates']
assert 'नमस्ते' in options, f'Expected Nepali option missing: {options!r}'
encoded = 'नमस्ते'.encode('utf-16-be')
units = ''.join(f'{int.from_bytes(encoded[i:i+2], "big"):04x}' for i in range(0, len(encoded), 2))
subprocess.run([adapter_test, units], check=True, timeout=5)
