#!/usr/bin/env python3
"""Report candidate inclusion on human-labeled Aksharantar test rows, not accuracy."""
import collections, json, pathlib, sys, zipfile
if len(sys.argv)!=3: raise SystemExit('Usage: python3 evaluate-aksharantar.py nep.zip indiccorp-index.tsv')
archive,index=map(pathlib.Path,sys.argv[1:]); targets=collections.defaultdict(list); grouped=collections.defaultdict(collections.Counter)
with zipfile.ZipFile(archive) as z,z.open('nep_test.json') as f:
 for line in f:
  r=json.loads(line); targets[r['english word']].append((r['native word'],r['source']));grouped[r['source']]['total']+=1
with index.open(encoding='utf8') as f:
 for line in f:
  fields=line.rstrip('\n').split('\t'); entries=targets.get(fields[0])
  if not entries:continue
  vals=fields[1:]
  for native,source in entries:
   grouped[source]['roman_key_seen']+=1
   if native in vals:grouped[source]['exact_pair_present']+=1
   if native in vals[:3]:grouped[source]['exact_pair_first3_lexical']+=1
# The split may contain overlapping keys or pairs with training, so this is not
# an independent generalization estimate. Human test rows are never added to index.
print(json.dumps({'sources':{k:dict(v) for k,v in sorted(grouped.items())},'note':'AK-Freq, AK-NEF and AK-NEI test rows compared against IndicCorp-only train; overlap is reported, not removed. No scores or counts used as frequencies. Lexical order is not a learned ranking.'},indent=2))
