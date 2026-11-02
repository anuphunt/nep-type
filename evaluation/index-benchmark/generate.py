#!/usr/bin/env python3
"""Stream an authorized TSV to build a deterministic benchmark workload.

Keys are derived from the measured index, not independent quality references.
Do not use the resulting data as held-out transliteration accuracy evidence.
"""
import argparse, hashlib, json, random, string
p=argparse.ArgumentParser();p.add_argument('index');p.add_argument('output');p.add_argument('--sample',type=int,default=3000);p.add_argument('--seed',type=int,default=20261030);a=p.parse_args()
rng=random.Random(a.seed)
missing=['zqv'+''.join(rng.choice(string.ascii_lowercase) for _ in range(24)) for _ in range(200)]
missing_set=set(missing); sample=[]; found=set(); sha=hashlib.sha256(); rows=0
with open(a.index,'rb') as f:
    for line in f:
        sha.update(line); parts=line.rstrip(b'\n').decode('utf-8').split('\t'); key=parts[0]
        if key in missing_set: found.add(key)
        rows+=1
        row={'key':key,'expected':parts[1:],'category':'sampled_existing'}
        if len(sample)<a.sample: sample.append(row)
        else:
            j=rng.randrange(rows)
            if j<a.sample: sample[j]=row
if len(sample)!=a.sample or found: raise SystemExit('insufficient rows or generated absence collision')
controls=['', 'hello world', 'example.com', 'x_y', 'नमस्ते', 'A'*128, '🙂']
work=sample+[{'key':key,'expected':[],'category':'verified_absent'} for key in missing]+[{'key':key,'expected':[],'category':'invalid_control'} for key in controls]
rng.shuffle(work)
with open(a.output,'w',encoding='utf8') as f:json.dump({'version':'index-benchmark-v1','source_sha256':sha.hexdigest(),'source_rows':rows,'seed':a.seed,'cases':work},f,ensure_ascii=False,indent=2)
print('Created',len(work),'queries from',rows,'index rows')
