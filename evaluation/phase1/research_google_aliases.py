#!/usr/bin/env python3
"""Exploratory alias coverage only; does not build a product index.

Usage: python3 research_google_aliases.py /path/to/google-ne-lexicon.tsv /path/to/corpus-v1.json
"""
import collections, hashlib, itertools, json, re, sys
from pathlib import Path
if len(sys.argv) != 3: raise SystemExit(__doc__)
lex=Path(sys.argv[1]); data=Path(sys.argv[2])
if hashlib.sha256(lex.read_bytes()).hexdigest() != 'a9f616db4ecc35ecde4e519e1438c5501d8574b3623d43370fb0089a31ea8a83': raise SystemExit('Unexpected source hash')
# Approximate phonemic-to-casual Roman mappings. These are NOT language rules
# vetted by speakers, and are intentionally bounded to avoid exponential growth.
variants={'ax':['a',''], 'aa':['a','aa'], 'jh':['j','jh'], 'tsh':['chh','ch'], 'ts':['ch'], 'tt':['t'], 'dd':['d'], 'nn':['n'], 'tth':['th'], 'ddh':['dh'], 'jhh':['jh'], 'w':['w','v'], 'axj':['ai','aiy'], 'aaj':['ai','aai'], 'aaw':['au','aau'], 'aawn':['aun','aun'], 'axw':['au'], 'axwn':['aun'], 'aan':['an','aan'], 'axn':['an'], 'in':['in'], 'un':['un'], 'en':['en'], 'oj':['oi'], 'aajn':['ain'], 'axjn':['ain'], 'ew':['ew'], 'ow':['ow'], 'own':['own'], 'ojn':['oin']}
targets=collections.defaultdict(set)
for item in json.loads(data.read_text())['cases']:
 for a in item['annotations']:
  if a['role']=='nepali': targets[a['token'].lower()].update(a['acceptable'])
matches=set(); seen=set(); inspected=0; skipped=0; candidate_count=0
sample=collections.defaultdict(set)
for line in lex.open(encoding='utf-8'):
 if line.startswith('#'): continue
 parts=line.rstrip('\n').split('\t')
 if len(parts)<2 or not re.fullmatch('[\u0900-\u097f\u200c\u200d]+',parts[0]): continue
 native,phonemes=parts[:2]; symbols=phonemes.replace('.',' ').split()
 choices=[]
 for symbol in symbols:
  if symbol in variants: choices.append(variants[symbol])
  elif re.fullmatch('[a-z]+',symbol): choices.append([symbol])
  else: choices=[];break
 if not choices: skipped+=1;continue
 inspected+=1
 # Cap at 64 aliases per spelling. Input order remains deterministic.
 for pieces in itertools.islice(itertools.product(*choices),64):
  alias=''.join(pieces)
  if not alias: continue
  candidate_count+=1
  if alias in targets:
   seen.add(alias)
   if native in targets[alias]: matches.add(alias)
  if int.from_bytes(hashlib.sha256(alias.encode()).digest()[:2],'big')<16: sample[alias].add(native)
print(json.dumps({'dataset_sha256':hashlib.sha256(lex.read_bytes()).hexdigest(),'native_rows_processed':inspected,'skipped':skipped,'max_aliases_per_row':64,'generated_alias_count_including_duplicates':candidate_count,'sampled_aliases':len(sample),'sampled_ambiguous_aliases':sum(len(v)>1 for v in sample.values()),'baseline_distinct_nepali_tokens':len(targets),'baseline_tokens_with_any_alias':len(seen),'baseline_tokens_with_intended_form_in_aliases':len(matches),'warnings':['Exploratory hand-designed phonemic approximations; not speaker reviewed','Baseline set is not independent or representative','Ambiguous aliases need rankings and cannot be committed automatically','No data or model score is used as frequency']},indent=2))
