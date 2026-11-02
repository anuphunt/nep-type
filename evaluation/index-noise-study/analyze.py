#!/usr/bin/env python3
"""Count proposed structural filters; neither applies them nor judges language."""
import collections, hashlib, json, pathlib, sys, unicodedata
index, fixture, out = map(pathlib.Path, sys.argv[1:])
examples = json.loads(fixture.read_text())
targets = collections.defaultdict(set)
for key, accepted in examples:
    targets[key].update(accepted)
flags = lambda s: {
    'leading_combining_mark': bool(s) and unicodedata.category(s[0]).startswith('M'),
    'joiner_at_boundary': bool(s) and (s[0] in '\u200c\u200d' or s[-1] in '\u200c\u200d'),
    'no_letter': not any(unicodedata.category(c).startswith('L') for c in s),
    'long_target_over_30_scalars': len(s) > 30,
}
counts=collections.Counter(); held=collections.Counter(); sample={}
with index.open(encoding='utf8') as f:
    for line in f:
        key,*vals=line.rstrip('\n').split('\t'); counts['keys']+=1
        if len(vals)>1: counts['collision_keys']+=1
        for i,value in enumerate(vals):
            counts['pairs']+=1
            for name,bad in flags(value).items():
                if bad:
                    counts[name]+=1
                    if i==0: counts[name+'_first_lexical']+=1
                    if len(sample.setdefault(name,[]))<8: sample[name].append([key,value])
        if key in targets:
            expected=targets[key]; matched=expected.intersection(vals)
            held['keys_seen']+=1
            if matched:
                held['keys_with_accepted_candidate']+=1
                for name in flags(vals[0]):
                    if not any(not flags(v)[name] for v in matched): held[name+'_lost_keys']+=1
result={'index_sha256':hashlib.sha256(index.read_bytes()).hexdigest(),'fixture_sha256':hashlib.sha256(fixture.read_bytes()).hexdigest(),'fixture_rows':len(examples),'counts':dict(counts),'fixture':dict(held),'examples_lexical_not_random':sample}
out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
