import collections, json, re, zipfile, hashlib, sys
from pathlib import Path

if len(sys.argv)!=3: raise SystemExit('Usage: python3 inspect_aksharantar.py /path/nep.zip /path/corpus-v1.json')
archive=Path(sys.argv[1])
if hashlib.sha256(archive.read_bytes()).hexdigest()!='8bdcc5957d701ea36b63c00c713b43bc30902774b70736737d480e77929de92c': raise SystemExit('Unexpected archive hash')
z=zipfile.ZipFile(archive)
corpus=json.loads(Path(sys.argv[2]).read_text())
targets=collections.defaultdict(set)
for case in corpus['cases']:
 for t in case['annotations']:
  if t['role']=='nepali': targets[t['token'].lower()].update(t['acceptable'])
counts=collections.Counter(); flags=collections.Counter(); targeted=collections.defaultdict(set); sample=collections.defaultdict(set); partitions={}
for n in ('nep_train.json','nep_valid.json','nep_test.json'):
 rows=collections.Counter()
 with z.open(n) as f:
  for line in f:
   o=json.loads(line); source=o.get('source','MISSING'); rows[source]+=1
   if n!='nep_train.json' or source!='IndicCorp': continue
   counts['rows']+=1
   latin=o.get('english word','');native=o.get('native word','')
   if not re.fullmatch('[a-z]+',latin): flags['non_lower_ascii']+=1
   if not re.fullmatch('[\u0900-\u097f\u200c\u200d]+',native): flags['non_devanagari']+=1
   if len(latin)<2: flags['one_letter']+=1
   if len(latin)>35: flags['long_roman']+=1
   if o.get('score') is None: flags['null_score']+=1
   if latin in targets: targeted[latin].add(native)
   if int.from_bytes(hashlib.sha256(latin.encode()).digest()[:2],'big') < 64: sample[latin].add(native)
 partitions[n]=dict(rows)
matched=sum(bool(targeted.get(k,set())&v) for k,v in targets.items())
print(json.dumps({'partitions':partitions,'indiccorp_train_flags':dict(flags),'sample_keys':len(sample),'sample_ambiguous_keys':sum(len(v)>1 for v in sample.values()),'sample_max_alternatives':max(map(len,sample.values())),'baseline_nepali_distinct_targets':len(targets),'baseline_targets_with_at_least_one_matching_form':matched,'baseline_targets_seen':sum(k in targeted for k in targets),'note':'Sample deterministic by roman-key SHA256; score never used as frequency. Pair matches measure candidate inclusion only; baseline was not independently held out.'},indent=2))
