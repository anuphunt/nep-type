#!/usr/bin/env python3
"""Development-only suffix-composition experiment; never changes Lekha."""
import json
import re
import time
from pathlib import Path

root = Path('/Users/anupdhakal/Desktop/apps/nepali-keyboard-prototype')
authored = json.loads((root / 'data/sources/nepali-authored-v1.json').read_text())
english = set()
with (root / 'data/sources/cmudict.dict').open(encoding='utf-8') as f:
    for line in f:
        if line.startswith(';;;') or not line.strip(): continue
        english.add(re.sub(r'\(\d+\)$', '', line.split()[0]).lower())

# Suffixes are explicit orthographic strings, not corpus frequency estimates.
suffixes = [('haru', 'हरू'), ('bata', 'बाट'), ('sanga', 'सँग'),
            ('lai', 'लाई'), ('ko', 'को'), ('ka', 'का'), ('ki', 'की'),
            ('le', 'ले'), ('ma', 'मा')]

def propose(token):
    # Limit to lowercase ASCII and known single-spelling authored stems.
    # Dictionary English is left alone even when it looks segmentable.
    if not re.fullmatch(r'[a-z]{4,32}', token) or token in english:
        return []
    out=[]
    for roman, native in suffixes:
        if not token.endswith(roman): continue
        stem=token[:-len(roman)]
        forms=authored.get(stem, [])
        if len(stem) < 3 or len(forms) != 1: continue
        candidate=forms[0] + native
        if candidate not in out: out.append(candidate)
        if len(out) == 2: break
    return out

def main():
    cases=json.loads((Path(__file__).parent / 'dev.json').read_text())
    indexed={}
    keys={c['roman'] for c in cases}
    for file in ['aksharantar-indiccorp-v1.tsv','google-ne-aliases.tsv']:
        with (root / 'data/compiled' / file).open(encoding='utf-8') as f:
            for line in f:
                fields=line.rstrip('\n').split('\t')
                if fields[0] in keys:
                    indexed.setdefault(fields[0],[]).extend(fields[1:])
    result=[]
    for case in cases:
        key=case['roman']; before=list(dict.fromkeys(authored.get(key,[])+indexed.get(key,[])))
        additions=[x for x in propose(key) if x not in before]
        expected=set(case['acceptable'])
        result.append({**case,'existing_first4':before[:4],'proposed':additions,'existing_available':bool(expected.intersection(before[:4]+[key])),
                       'proposed_available':bool(expected.intersection((before+additions)[:4]+[key]))})
    for kind in sorted({r['kind'] for r in result}):
        rs=[r for r in result if r['kind']==kind]
        print(kind,'count',len(rs),'existing',sum(r['existing_available'] for r in rs),
              'after_top4',sum(r['proposed_available'] for r in rs),'with_new',sum(bool(r['proposed']) for r in rs))
    # Deliberately keep full results, including poor alternatives, for review.
    (Path(__file__).parent/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    start=time.perf_counter()
    for _ in range(1000):
        for c in cases: propose(c['roman'])
    print('warm_python_us_per_lookup',round((time.perf_counter()-start)*1e6/(len(cases)*1000),3))

if __name__ == '__main__': main()
