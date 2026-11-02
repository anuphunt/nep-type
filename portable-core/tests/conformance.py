#!/usr/bin/env python3
"""Protocol-level checks. No host application or platform IME is exercised."""
import json
import os
import subprocess
import sys

exe = sys.argv[1]
commands = [
 {"id":"a","op":"create"},
 {"id":"a","op":"create"},
 {"id":"b","op":"create"},
 {"id":"a","op":"append","text":"ma"},
 {"id":"a","op":"set_language","language":"english"},
 {"id":"a","op":"destroy"},
 {"id":"b","op":"state"},
 {"id":"a","op":"cancel"},
 {"id":"a","op":"set_language","language":"english"},
 {"id":"a","op":"append","text":"hello"},
 {"id":"a","op":"set_language","language":"nepali"},
 {"id":"a","op":"append","text":"mero"},
 {"id":"a","op":"commit","keepContext":True},
 {"id":"a","op":"append","text":"man"},
 {"id":"a","op":"select","text":"man"},
 {"id":"a","op":"commit"},
 {"id":"a","op":"append","text":"नमस्ते"},
 {"id":"a","op":"append","text":"a b"},
 {"id":"a","op":"backspace"},
 {"id":"a","op":"append","text":"example.com"},
 {"id":"a","op":"commit"},
 {"id":"a","op":"append","text":"`git"},
 {"id":"a","op":"commit","keepLiteralState":True},
 {"id":"a","op":"append","text":"push`"},
 {"id":"a","op":"commit","keepLiteralState":True},
 {"id":"a","op":"append","text":"ma"},
 {"id":"a","op":"cancel"},
 {"id":"a","op":"destroy"},
 {"id":"a","op":"state"},
 {"id":"b","op":"destroy"},
]
run = subprocess.run([exe], input="".join(json.dumps(c, ensure_ascii=False)+"\n" for c in commands), text=True, capture_output=True, check=True, env=os.environ.copy())
r = [json.loads(line) for line in run.stdout.splitlines()]
assert len(r) == len(commands), (len(r), run.stderr)
assert r[0]["ok"] and not r[0]["state"]["composing"]
assert not r[1]["ok"] and r[1]["error"] == "session already exists"
assert r[3]["accepted"] and r[3]["state"]["markedText"] == "म"
assert "ma" in r[3]["state"]["candidates"]
assert not r[4]["ok"] and r[4]["state"]["roman"] == "ma"
assert not r[5]["ok"] and r[5]["state"]["roman"] == "ma"
assert r[6]["state"]["roman"] == ""  # independent sessions
assert r[7]["result"] == "ma"
assert r[8]["state"]["language"] == "english" and not r[9]["accepted"]
assert r[12]["result"] == "मेरो" and r[13]["state"]["markedText"] == "मन"
assert r[14]["accepted"] and r[15]["result"] == "man"
assert not r[16]["accepted"] and not r[17]["accepted"] and not r[18]["accepted"]
assert r[19]["state"]["markedText"] == "example.com" and r[20]["result"] == "example.com"
assert r[21]["state"]["markedText"] == "`git" and r[22]["result"] == "`git"
assert r[23]["state"]["markedText"] == "push`" and r[24]["result"] == "push`"
assert r[25]["state"]["markedText"] == "म" and r[26]["result"] == "ma"
assert r[27]["ok"] and not r[28]["ok"] and r[29]["ok"]
print(f"PASS: {len(commands)} protocol requests; composition, original, context, literal spans, session isolation and loss guards")

# Punctuation must not carry language context into the next word, and a
# Nepali stop remains reversible if the user chooses the original token.
boundary_commands = [
    {"id":"punct", "op":"create"}, {"id":"solo", "op":"create"},
    {"id":"punct", "op":"append", "text":"the."},
    {"id":"punct", "op":"commit", "keepContext":True},
    {"id":"punct", "op":"append", "text":"man"},
    {"id":"solo", "op":"append", "text":"man"},
    {"id":"punct", "op":"cancel"},
    {"id":"punct", "op":"append", "text":"namaste."},
    {"id":"punct", "op":"select", "text":"namaste."},
    {"id":"punct", "op":"commit", "keepContext":True},
    {"id":"punct", "op":"append", "text":"ma."},
    {"id":"punct", "op":"append", "text":"com"},
    {"id":"punct", "op":"cancel"},
]
boundary = subprocess.run([exe], input="".join(json.dumps(c)+"\n" for c in boundary_commands),
                          text=True, capture_output=True, check=True, env=os.environ.copy())
b = [json.loads(line) for line in boundary.stdout.splitlines()]
assert len(b) == len(boundary_commands)
assert b[4]["state"]["markedText"] == b[5]["state"]["markedText"]
assert b[7]["state"]["markedText"] == "नमस्ते।" and "namaste." in b[7]["state"]["candidates"]
assert b[8]["accepted"] and b[9]["result"] == "namaste."
assert b[10]["state"]["markedText"] == "म।" and b[11]["state"]["markedText"] == "ma.com"
assert b[12]["result"] == "ma.com"
print("PASS: punctuation boundary, original selection and emerging URL")

# All Nepali is an explicit shared-engine mode; preserve an original choice.
all_nepali_commands = [
    {"id":"all", "op":"create"},
    {"id":"all", "op":"set_language", "language":"allNepali"},
    {"id":"all", "op":"append", "text":"office"},
    {"id":"all", "op":"select", "text":"office"},
    {"id":"all", "op":"commit"},
    {"id":"all", "op":"append", "text":"example.com"},
    {"id":"all", "op":"cancel"},
]
all_run = subprocess.run([exe], input="".join(json.dumps(c)+"\n" for c in all_nepali_commands),
                         text=True, capture_output=True, check=True, env=os.environ.copy())
a = [json.loads(line) for line in all_run.stdout.splitlines()]
assert len(a) == len(all_nepali_commands) and a[1]["ok"]
assert a[2]["accepted"] and a[2]["state"]["markedText"] != "office" and "office" in a[2]["state"]["candidates"]
assert a[3]["accepted"] and a[4]["result"] == "office"
assert a[5]["state"]["markedText"] == "example.com" and a[6]["result"] == "example.com"
print("PASS: All Nepali composition, original choice and literal protection")

# A live adapter must receive a response without closing stdin. This checks
# transport delivery only; it does not make blocking IPC suitable for an IME.
import select
live = subprocess.Popen([exe], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    live.stdin.write(json.dumps({"id":"live", "op":"create"}) + "\n")
    live.stdin.flush()
    assert select.select([live.stdout], [], [], 3)[0], "response was not delivered while stdin remained open"
    assert json.loads(live.stdout.readline())["ok"]
finally:
    live.stdin.close()
    live.wait(timeout=3)
print("PASS: live response delivered before closing stdin")
