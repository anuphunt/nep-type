#!/usr/bin/env python3
"""Small hand-labelled development diagnostic, not independent accuracy evaluation."""
import json, os, subprocess
from pathlib import Path
p=Path('/Users/anupdhakal/Desktop/apps/nepali-keyboard-prototype')
# Intent labels are illustrative and need native-speaker review; no private text.
cases=[('mero','man','मन'),('the','man','man'),('mero','ghar','घर'),('the','home','home'),('yo','pani','पानी'),('ma','pani','पनि'),('the','book','book'),('mero','kitab','किताब'),('ramro','cha','छ'),('a','car','car'),('mero','phone','phone'),('the','phone','phone'),('tapai','le','ले'),('yo','kalam','कलम'),('ma','bholi','भोलि'),('the','bank','bank'),('ma','bank','bank'),('aaja','office','office'),('the','school','school'),('mero','sathi','साथी'),('yo','kukur','कुकुर'),('the','cat','cat'),('ma','khana','खाना'),('aaja','padhchu','पढ्छु'),('mero','naam','नाम'),('the','name','name'),('mero','football','फुटबल'),('the','football','football'),('this','is','is'),('malai','geet','गीत')]
requests=[]
for i,(prev,word,_) in enumerate(cases):
    for op in ({'op':'create'},{'op':'append','text':prev},{'op':'commit','keepContext':True},{'op':'append','text':word}): requests.append(dict(id=str(i),**op))
mined=str(p/'data/compiled/aksharantar-indiccorp-v1.tsv'); google=str(p/'data/compiled/google-ne-aliases.tsv'); authored=str(p/'platforms/android/app/src/main/assets/nepali-authored-v1.tsv')
env=dict(os.environ,NEPTYPE_AKSHARANTAR_INDEX=mined,NEPTYPE_ALIAS_INDEX=google)
swift=subprocess.run(['/tmp/neptype-rank-swift/debug/neptype-conformance'],input=''.join(json.dumps(x)+'\n' for x in requests),text=True,capture_output=True,check=True,env=env)
resp=[json.loads(x) for x in swift.stdout.splitlines()]
assert len(resp)==4*len(cases)
java=subprocess.run(['/opt/homebrew/opt/openjdk/bin/java','-cp','rank-investigation/classes','ServiceLookup',authored,mined,google],input=''.join(w+'\n' for _,w,_ in cases),text=True,capture_output=True,check=True)
lines=java.stdout.splitlines(); assert len(lines)==len(cases)
rows=[]
for i,((prev,word,want),line) in enumerate(zip(cases,lines)):
    state=resp[4*i+3]; assert state['ok'] and state['accepted']
    s=state['state']['candidates']; a=line.split('\t') if line else []
    rows.append(dict(context=prev,word=word,intended=want,swift=s,android=a,swift_preferred=state['state']['markedText'],android_original=word))
summary={'cases':len(rows),'swift_preferred_matches_label':sum(x['swift_preferred']==x['intended'] for x in rows),'swift_label_in_candidates':sum(x['intended'] in x['swift'] for x in rows),'android_label_in_suggestions_or_original':sum(x['intended']==x['word'] or x['intended'] in x['android'] for x in rows),'first_nepali_order_agrees':sum(next((c for c in x['swift'] if c!=x['word']),None)==next(iter(x['android']),None) for x in rows),'swift_original_available':sum(x['word'] in x['swift'] for x in rows)}
print(json.dumps({'summary':summary,'cases':rows},ensure_ascii=False,indent=2))
