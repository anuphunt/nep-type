#!/usr/bin/env python3
"""Check missing index behavior in pure engines; does not simulate host UI."""
import json, os, subprocess, sys

swift_exe, java_exe, classes = sys.argv[1:]
missing = "/this-path-is-intentionally-absent-lekha-consistency"
words=["namaste","bhaisakeko","pani","football"]
requests=[]
for i,word in enumerate(words):
    requests.extend([{"id":str(i),"op":"create"}, {"id":str(i),"op":"append","text":word}])
env=dict(os.environ, LEKHA_AKSHARANTAR_INDEX=missing, LEKHA_ALIAS_INDEX=missing)
p=subprocess.run([swift_exe],input="".join(json.dumps(x)+"\n" for x in requests),capture_output=True,text=True,check=True,env=env)
rows=[json.loads(x) for x in p.stdout.splitlines()]
assert len(rows)==2*len(words)
for i,word in enumerate(words):
    state=rows[2*i+1]["state"]
    assert word in state["candidates"] and state["roman"] == word
p=subprocess.run([java_exe,"-cp",classes,"ServiceLookup",missing,missing,missing],input="".join(w+"\n" for w in words),capture_output=True,text=True,check=True)
assert p.stdout == "\n"*len(words), repr(p.stdout)
print("PASS: missing indexes preserve Swift original and return no Java index choices")
print("Android original is a separate UI control; native UI and host behavior were not tested.")
