#!/usr/bin/env python3
"""Deterministically sample index rows for implementation checks, not accuracy."""
import json, random, sys
randomizer=random.Random(20261030)
size=int(sys.argv[2]); reservoir=[]; eligible=0
with open(sys.argv[1], encoding="utf-8") as source:
    for line in source:
        fields=line.rstrip("\n").split("\t")
        key=fields[0]
        if len(fields)<2 or not (3<=len(key)<=32) or not key.isascii() or not key.isalpha() or not key.islower(): continue
        eligible+=1
        entry={"roman":key,"first_indexed":fields[1]}
        if len(reservoir)<size: reservoir.append(entry)
        else:
            j=randomizer.randrange(eligible)
            if j<size: reservoir[j]=entry
assert len(reservoir)==size
print(json.dumps({"seed":20261030,"eligible_rows":eligible,"note":"Deterministic within this index; first indexed candidate is not a label or frequency estimate.","cases":sorted(reservoir,key=lambda x:x["roman"])},ensure_ascii=False,indent=2))
