#!/usr/bin/env python3
"""Cross-engine diagnostics using authored data, never an accuracy benchmark."""
import json, os, subprocess, sys

swift_exe, java_exe, classes, curated, mined, google, authored = sys.argv[1:]
data = json.load(open(authored, encoding="utf-8"))
items = sorted(data.items())
requests = []
for i, (word, _) in enumerate(items):
    requests.extend([{"id":str(i),"op":"create"}, {"id":str(i),"op":"append","text":word}])
environment = dict(os.environ, LEKHA_AKSHARANTAR_INDEX=mined, LEKHA_ALIAS_INDEX=google)
swift = subprocess.run([swift_exe],input="".join(json.dumps(x)+"\n" for x in requests),text=True,capture_output=True,check=True,env=environment)
responses=[json.loads(line) for line in swift.stdout.splitlines()]
android=subprocess.run([java_exe,"-cp",classes,"ServiceLookup",curated,mined,google],input="".join(word+"\n" for word,_ in items),text=True,capture_output=True,check=True)
lines=android.stdout.splitlines()
assert len(lines)==len(items) and len(responses)==len(items)*2
rows=[]
for i,((word,expected),line) in enumerate(zip(items,lines)):
    response=responses[2*i+1]
    assert response["ok"] and response["accepted"]
    swift_choices=response["state"]["candidates"]
    android_choices=line.split("\t") if line else []
    expected_set=set(expected)
    rows.append({"roman":word,"expected":expected,"swift_choices":swift_choices,"android_choices":android_choices,
      "swift_authored_any":bool(expected_set.intersection(swift_choices)),
      "android_authored_any":bool(expected_set.intersection(android_choices)),
      "swift_authored_all":expected_set.issubset(swift_choices),
      "android_authored_all":expected_set.issubset(android_choices),
      "original_retained":word in swift_choices,
      "first_nepali_equal":next((s for s in swift_choices if s != word),None)==next(iter(android_choices),None)})
summary={"authored_keys":len(rows)}
for field in ("swift_authored_any","android_authored_any","swift_authored_all","android_authored_all","original_retained","first_nepali_equal"):
    summary[field]=sum(row[field] for row in rows)
print(json.dumps({"summary":summary,"caveat":"Implementation consistency on source-authored entries; circular by construction, not held-out accuracy or native-host behavior. Android original is a separate UI control and is not included in Android choices. Swift comparison is isolated word without neighboring context.","cases":rows},ensure_ascii=False,indent=2))
