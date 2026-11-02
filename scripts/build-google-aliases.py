#!/usr/bin/env python3
"""Compile CC BY 4.0 Google Nepali pronunciations into experimental aliases."""
import collections, hashlib, itertools, json, pathlib, re, sys
root=pathlib.Path(__file__).resolve().parent.parent
source=root/'data/sources/google-ne-lexicon.tsv'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='a9f616db4ecc35ecde4e519e1438c5501d8574b3623d43370fb0089a31ea8a83', 'Source hash mismatch'
variants={'ax':['a',''], 'aa':['a','aa'], 'jh':['j','jh'], 'tsh':['chh','ch'], 'ts':['ch'], 'tt':['t'], 'dd':['d'], 'nn':['n'], 'tth':['th'], 'ddh':['dh'], 'jhh':['jh'], 'w':['w','v'], 'axj':['ai','aiy'], 'aaj':['ai','aai'], 'aaw':['au','aau'], 'aawn':['aun','aun'], 'axw':['au'], 'axwn':['aun'], 'aan':['an','aan'], 'axn':['an'], 'in':['in'], 'un':['un'], 'en':['en'], 'oj':['oi'], 'aajn':['ain'], 'axjn':['ain'], 'ew':['ew'], 'ow':['ow'], 'own':['own'], 'ojn':['oin']}
index=collections.defaultdict(set);processed=skipped=0
for line in source.open(encoding='utf-8'):
 if line.startswith('#'):continue
 parts=line.rstrip('\n').split('\t')
 if len(parts)<2 or not re.fullmatch('[\u0900-\u097f\u200c\u200d]+',parts[0]):continue
 native,phonemes=parts[:2];choices=[]
 for symbol in phonemes.replace('.',' ').split():
  if symbol in variants: choices.append(variants[symbol])
  elif re.fullmatch('[a-z]+',symbol): choices.append([symbol])
  else:choices=[];break
 if not choices:skipped+=1;continue
 processed+=1
 for parts in itertools.islice(itertools.product(*choices),64):
  alias=''.join(parts)
  if 2<=len(alias)<=35:index[alias].add(native)
# Lexical ordering is deterministic, not a frequency, confidence, or accuracy ranking.
# Keep all candidates in the data; UI selects within its fixed display budget.
out=root/'data/compiled/google-ne-aliases.tsv';out.parent.mkdir(parents=True,exist_ok=True)
with out.open('w',encoding='utf-8') as f:
 for k in sorted(index):f.write(k+'\t'+'\t'.join(sorted(index[k]))+'\n')
heldout=json.loads((root/'evaluation/phase1/alias-holdout-v1.json').read_text())
counts=collections.Counter()
for roman,refs in heldout:
 candidates=sorted(index.get(roman,()))
 counts['total']+=1
 counts['found_any']+=bool(candidates)
 counts['recall_all']+=any(r in candidates for r in refs)
 counts['recall_first_3_lexicographic']+=any(r in candidates[:3] for r in refs)
print(json.dumps({'keys':len(index),'pairs':sum(len(v) for v in index.values()),'colliding_keys':sum(len(v)>1 for v in index.values()),'max_candidates':max(map(len,index.values())),'source_rows_processed':processed,'skipped':skipped,'file_bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'heldout':dict(counts)},indent=2))
