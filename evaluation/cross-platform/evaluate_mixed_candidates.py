#!/usr/bin/env python3
"""Compare isolated-token candidate recall on a previously used mixed corpus."""
import collections, json, os, subprocess, sys

harness, classes, index_a, index_g, curated, fixture = sys.argv[1:]
cases = json.load(open(fixture, encoding="utf-8"))["cases"]
items = [(case["id"], annotation) for case in cases for annotation in case["annotations"]]
commands = []
for i, (_, a) in enumerate(items):
    commands.extend([{"id":str(i),"op":"create"}, {"id":str(i),"op":"append","text":a["token"]}])
env = dict(os.environ, NEPTYPE_AKSHARANTAR_INDEX=index_a, NEPTYPE_ALIAS_INDEX=index_g)
swift = subprocess.run([harness], input="".join(json.dumps(c)+"\n" for c in commands), text=True, capture_output=True, env=env, check=True)
responses = [json.loads(line) for line in swift.stdout.splitlines()]
java = subprocess.run(["java","-cp",classes,"CandidateProbe",index_a,index_g,curated], input="".join(a["token"]+"\n" for _,a in items), text=True, capture_output=True, check=True)
lines=java.stdout.splitlines()
assert len(responses)==2*len(items) and len(lines)==len(items)
summary=collections.defaultdict(lambda: {"tokens":0,"swift_any":0,"android_any":0})
details=[]
for i,(case,a) in enumerate(items):
    state=responses[2*i+1].get("state") or {}
    raw=a["token"]
    swift_candidates=state.get("candidates",[])
    android_candidates=[raw]+(lines[i].split("\t") if lines[i] else [])
    expected=a["acceptable"]
    s=any(value in swift_candidates for value in expected)
    j=any(value in android_candidates for value in expected)
    role=a["role"]
    summary[role]["tokens"]+=1; summary[role]["swift_any"]+=s; summary[role]["android_any"]+=j
    details.append({"case":case,"token":raw,"role":role,"expected":expected,"swift_match":s,"android_match":j})
print(json.dumps({"case_count":len(cases),"summary":summary,"details":details,"caveat":"Previously inspected synthetic fixture; isolated tokens, no context or real typing. Android original is included as an option, not automatic language identification."},ensure_ascii=False,indent=2))
