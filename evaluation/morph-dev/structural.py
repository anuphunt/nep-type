#!/usr/bin/env python3
"""Cross-check generated combinations with mined rows; not labeled accuracy."""
import json
from pathlib import Path
from experiment import authored, propose, root, suffixes

keys={base+suffix for base,forms in authored.items() if len(forms)==1 for suffix,_ in suffixes}
rows={}
with (root/'data/compiled/aksharantar-indiccorp-v1.tsv').open(encoding='utf-8') as f:
    for line in f:
        fields=line.rstrip('\n').split('\t')
        if fields[0] in keys: rows[fields[0]]=fields[1:]
results=[]
for key in sorted(rows):
    candidate=propose(key)
    if candidate:
        results.append({'roman':key,'indexed':rows[key],'proposed':candidate,
                        'agrees':bool(set(candidate).intersection(rows[key]))})
output={'count':len(results),'agrees':sum(x['agrees'] for x in results),
        'disagrees':sum(not x['agrees'] for x in results),'rows':results,
        'caveat':'Mined spelling may be wrong or represent different sense; disagreement is not a labeled error rate.'}
(Path(__file__).parent/'structural-results.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
print(output['count'],output['agrees'],output['disagrees'])
