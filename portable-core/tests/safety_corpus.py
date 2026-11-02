#!/usr/bin/env python3
"""Deterministic raw-input preservation checks for the protocol; not OS host tests."""
import json
import os
import random
import string
import subprocess
import sys

executable = sys.argv[1]
literal = ["https://example.com/a?x=1", "USER@EXAMPLE.COM", "www.example.org",
           "config.json", "obj.method", "my_variable", "camelCase", "42bytes",
           "src/core/file.swift", "`inline", "name@example.com"]
rng = random.Random(711204)
alphabet = string.ascii_letters + string.digits + string.punctuation
tokens = literal + ["".join(rng.choice(alphabet) for _ in range(rng.randint(1, 70))) for _ in range(500)]
requests = [{"id": "safe", "op": "create"}]
for token in tokens:
    requests += [{"id": "safe", "op": "append", "text": token},
                 {"id": "safe", "op": "cancel"}]
proc = subprocess.run([executable], input="".join(json.dumps(x) + "\n" for x in requests),
                      text=True, capture_output=True, env=os.environ.copy(), check=True)
responses = [json.loads(line) for line in proc.stdout.splitlines()]
assert len(responses) == len(requests), (len(responses), len(requests), proc.stderr)
for i, token in enumerate(tokens):
    append, cancel = responses[1 + 2*i : 3 + 2*i]
    assert append["ok"] and append["accepted"], (token, append)
    assert append["state"]["roman"] == token, (token, append)
    assert token in append["state"]["candidates"], (token, append)
    assert cancel["result"] == token, (token, cancel)
    if i < len(literal):
        assert append["state"]["markedText"] == token, (token, append)
print(f"PASS: {len(tokens)} deterministic ASCII tokens retain exact original and remain cancellable; {len(literal)} code/URL examples remain literal")
