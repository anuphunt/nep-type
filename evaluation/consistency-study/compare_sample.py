#!/usr/bin/env python3
"""Compare adapter candidates on sampled indexed rows; not ground truth."""
import json, os, subprocess, sys
swift_exe, java_exe, classes, curated, mined, google, fixture = sys.argv[1:]
items=json.load(open(fixture,encoding="utf-8"))["cases"]
requests=[]
for i,item in enumerate(items): requests.extend([{"id":str(i),"op":"create"},{"id":str(i),"op":"append","text":item["roman"]}])
env=dict(os.environ,NEPTYPE_AKSHARANTAR_INDEX=mined,NEPTYPE_ALIAS_INDEX=google)
raw=subprocess.run([swift_exe],input="".join(json.dumps(x)+"\n" for x in requests),capture_output=True,text=True,check=True,env=env)
swift=[json.loads(x) for x in raw.stdout.splitlines()]
raw=subprocess.run([java_exe,"-cp",classes,"ServiceLookup",curated,mined,google],input="".join(x["roman"]+"\n" for x in items),capture_output=True,text=True,check=True)
android=raw.stdout.splitlines()
assert len(swift)==2*len(items) and len(android)==len(items)
rows=[]
for i,(item,line) in enumerate(zip(items,android)):
    state=swift[2*i+1]["state"]; choices=state["candidates"]; a=line.split("\t") if line else []
    indexed=item["first_indexed"]
    rows.append({**item,"swift_original":item["roman"] in choices,"swift_top":state["markedText"],"swift_indexed_any":indexed in choices,"swift_indexed_first_four":indexed in choices[:4],"android_indexed_four":indexed in a,"android_choices":a,"swift_first_four":choices[:4]})
fields=("swift_original","swift_indexed_any","swift_indexed_first_four","android_indexed_four")
print(json.dumps({"summary":{"total":len(rows),**{f:sum(row[f] for row in rows) for f in fields},"swift_auto_roman":sum(row["swift_top"]==row["roman"] for row in rows)},"note":"Index-derived synthetic sample; first indexed reading is not ground truth, frequency, language intent or an accuracy label. Android preserves original as a separate default UI control.","cases":rows},ensure_ascii=False,indent=2))
