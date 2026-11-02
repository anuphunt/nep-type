#!/usr/bin/env python3
"""Write frozen, manually authored synthetic references; never invokes NepType."""
import hashlib, json
from pathlib import Path

# Roman spellings and references are illustrative; no claim of exhaustive
# romanization, dialect coverage, or expert linguistic review is made.
daily = [
 ('jhyaal',['झ्याल']),('dhoka',['ढोका']),('chhata',['छाता']),('chhano',['छानो']),
 ('bhitta',['भित्ता']),('chulo',['चुलो']),('bhada',['भाँडा','भाडा']),('khursani',['खुर्सानी']),
 ('golbheda',['गोलभेडा']),('mula',['मुला']),('ghadi',['घडी']),('jhola',['झोला']),
 ('kapada',['कपडा']),('sirani',['सिरानी']),('ochhyan',['ओछ्यान']),('kambal',['कम्बल']),
 ('chappal',['चप्पल']),('chabi',['चाबी']),('kaichi',['कैंची','कैँची']),('siyo',['सियो'])]
actions = [
 ('pakaaunu',['पकाउनु']),('hasnu',['हाँस्नु','हास्नु']),('runu',['रुनु']),('siknu',['सिक्नु']),
 ('hiddnu',['हिँड्नु','हिड्नु']),('basnu',['बस्नु']),('uthnu',['उठ्नु']),('sutnu',['सुत्नु']),
 ('bolnu',['बोल्नु']),('sodhnu',['सोध्नु']),('sunnu',['सुन्नु']),('hernu',['हेर्नु']),
 ('khannu',['खन्नु']),('tipnu',['टिप्नु']),('kinne',['किन्ने']),('bechnu',['बेच्नु']),
 ('rakhnu',['राख्नु']),('lyaaunu',['ल्याउनु']),('samjhana',['सम्झना']),('bujhnu',['बुझ्नु'])]
inflections = [
 ('garchhu',['गर्छु']),('garnechhu',['गर्नेछु']),('gareko',['गरेको']),('gariraheko',['गरिरहेको']),
 ('jaanchhu',['जान्छु']),('gaye',['गएँ','गए']),('aaye',['आएँ','आए']),('aauchu',['आउँछु','आउछु']),
 ('khayau',['खायौ']),('khanchhan',['खान्छन्']),('padheko',['पढेको']),('padhchhu',['पढ्छु']),
 ('lekheko',['लेखेको']),('lekhchhu',['लेख्छु']),('baseko',['बसेको']),('baschhan',['बस्छन्']),
 ('utheko',['उठेको']),('uthechhu',['उठेछु']),('boleko',['बोलेको']),('bolchhan',['बोल्छन्'])]
# Alternate ASCII Roman spellings are intentionally paired so the evaluator
# can compare recall across variants of the same intended Nepali word.
variants = [
 ('safaai',['सफाइ']),('safai',['सफाइ']),('bidaai',['बिदाइ']),('bidai',['बिदाइ']),
 ('aaja',['आज']),('aja',['आज']),('aankha',['आँखा']),('ankha',['आँखा']),
 ('saath',['साथ']),('sath',['साथ']),('maato',['माटो']),('mato',['माटो']),
 ('dudh',['दूध']),('doodh',['दूध']),('chhaayaa',['छाया']),('chhaya',['छाया']),
 ('saano',['सानो']),('sano',['सानो']),('bhok',['भोक']),('bhook',['भोक'])]
english = ['forecast','printer','receipt','glasses','notebook','calendar','subscription','airport','reliable','password']
names = ['Maya','Arjun','Sita','Kiran','Nisha','Rohan','Asha','Rita','Suman','Niraj']
assert len(daily)==len(actions)==len(inflections)==len(variants)==20
cases=[]
for category, values in [('daily',daily),('actions',actions),('inflections',inflections),('variant_spellings',variants)]:
    for roman, acceptable in values:
        cases.append(dict(id=f'T{len(cases)+1:03}',category=category,role='nepali',roman=roman,acceptable=acceptable))
for category, values in [('english_control',english),('name_control',names)]:
    for roman in values:
        cases.append(dict(id=f'T{len(cases)+1:03}',category=category,role='english' if category=='english_control' else 'name',roman=roman,acceptable=[roman]))
assert len(cases)==100
assert len({x["roman"] for x in cases}) == len(cases)
payload={'version':'probe-third-v1','description':'Untouched synthetic spelling variants and original-preservation controls; AI-authored, unreviewed, nonrepresentative.','cases':cases}
path=Path(__file__).with_name('corpus.json')
data=(json.dumps(payload,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
path.write_bytes(data)
print(hashlib.sha256(data).hexdigest())
