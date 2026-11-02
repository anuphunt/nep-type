#!/usr/bin/env python3
"""Compare candidate availability on a tiny illustrative fixture, not accuracy."""
import json, os, subprocess, sys

harness, classes, index_a, index_g, curated = sys.argv[1:]
fixture = [("namaste", "नमस्ते"), ("mero", "मेरो"), ("pani", "पानी"),
           ("ma", "म"), ("man", "मन"), ("bhaisakeko", "भइसकेको"),
           ("football", "फुटबल"), ("ramro", "राम्रो")]
env = dict(os.environ, NEPTYPE_AKSHARANTAR_INDEX=index_a, NEPTYPE_ALIAS_INDEX=index_g)
commands = []
for i, (word, _) in enumerate(fixture):
    sid = str(i)
    commands.extend([{"id": sid, "op":"create"}, {"id":sid, "op":"append", "text":word}])
run = subprocess.run([harness], input="".join(json.dumps(c)+"\n" for c in commands), text=True, capture_output=True, env=env, check=True)
rows = [json.loads(line) for line in run.stdout.splitlines()]
java = subprocess.run(["java", "-cp", classes, "CandidateProbe", index_a, index_g, curated], input="".join(w+"\n" for w,_ in fixture), text=True, capture_output=True, check=True)
lines = java.stdout.splitlines()
assert len(lines) == len(fixture)
results=[]
for i, ((word, expected), raw) in enumerate(zip(fixture, lines)):
    swift = rows[i*2+1]["state"]["candidates"]
    android = raw.split("\t") if raw else []
    results.append({"roman":word,"example":expected,"swift_has":expected in swift,"android_has":expected in android,"swift_candidates":swift,"android_candidates":android})
print(json.dumps({"note":"Illustrative, hand-picked examples, not a held-out accuracy evaluation; Android does not use Swift ranking.","results":results},ensure_ascii=False,indent=2))
