#!/usr/bin/env python3
"""Compare candidate recall on an existing fixture; no typing or host apps tested."""
import json, os, subprocess, sys

harness, classes, index_a, index_g, curated, fixture = sys.argv[1:]
examples = json.load(open(fixture, encoding="utf-8"))
commands = []
for i, (word, _) in enumerate(examples):
    commands.extend([{"id": str(i), "op": "create"}, {"id": str(i), "op": "append", "text": word}])
env = dict(os.environ, LEKHA_AKSHARANTAR_INDEX=index_a, LEKHA_ALIAS_INDEX=index_g)
swift = subprocess.run([harness], input="".join(json.dumps(c)+"\n" for c in commands), text=True, capture_output=True, env=env, check=True)
responses = [json.loads(line) for line in swift.stdout.splitlines()]
java = subprocess.run(["java", "-cp", classes, "CandidateProbe", index_a, index_g, curated], input="".join(word+"\n" for word, _ in examples), text=True, capture_output=True, check=True)
lines = java.stdout.splitlines()
assert len(responses) == 2*len(examples) and len(lines) == len(examples)
results=[]
for i, (word, expected) in enumerate(examples):
    s = responses[2*i+1]["state"]["candidates"]
    j = lines[i].split("\t") if lines[i] else []
    results.append({"roman":word, "expected":expected, "swift_match":any(v in s for v in expected), "android_match":any(v in j for v in expected), "swift_candidates":s, "android_candidates":j})
print(json.dumps({"fixture":fixture,"count":len(results),"swift_candidates_any":sum(r["swift_match"] for r in results),"android_candidates_any":sum(r["android_match"] for r in results),"caveat":"Earlier hand-curated Google-alias holdout, not independent of current curated and Aksharantar indexes; no context, host input or typing accuracy measured.","results":results},ensure_ascii=False,indent=2))
