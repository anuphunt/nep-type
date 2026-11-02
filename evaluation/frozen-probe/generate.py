#!/usr/bin/env python3
"""Emit frozen synthetic references. Does not invoke or inspect NepType."""
import json
from pathlib import Path

# annotations: roman/source token, intended role, acceptable token spellings.
# Sentence alternatives and token alternatives describe intended reading only.
ROWS = [
('english','Please close the window before dinner.','Please close the window before dinner.','Please|english|Please;window|english|window;dinner|english|dinner'),
('english','Our train arrives early on Friday.','Our train arrives early on Friday.','train|english|train;arrives|english|arrives;Friday|english|Friday'),
('english','The small garden needs more water.','The small garden needs more water.','garden|english|garden;needs|english|needs;water|english|water'),
('english','She will bring the red notebook.','She will bring the red notebook.','bring|english|bring;red|english|red;notebook|english|notebook'),
('english','A quiet room helps me concentrate.','A quiet room helps me concentrate.','quiet|english|quiet;room|english|room;concentrate|english|concentrate'),
('english','We bought fresh bread this morning.','We bought fresh bread this morning.','bought|english|bought;bread|english|bread;morning|english|morning'),
('english','Can your brother repair this bicycle?','Can your brother repair this bicycle?','brother|english|brother;repair|english|repair;bicycle|english|bicycle'),
('english','They watched birds beside the river.','They watched birds beside the river.','watched|english|watched;birds|english|birds;river|english|river'),
('english','Please leave my shoes near the door.','Please leave my shoes near the door.','leave|english|leave;shoes|english|shoes;door|english|door'),
('english','The music was surprisingly loud tonight.','The music was surprisingly loud tonight.','music|english|music;surprisingly|english|surprisingly;loud|english|loud'),
('nepali','aaja gham lageko cha.','आज घाम लागेको छ.','aaja|nepali|आज;gham|nepali|घाम;lageko|nepali|लागेको;cha|nepali|छ'),
('nepali','timi kaha baschau?','तिमी कहाँ बस्छौ?','timi|nepali|तिमी;kaha|nepali|कहाँ;baschau|nepali|बस्छौ'),
('nepali','yo kitab dherai ramro cha.','यो किताब धेरै राम्रो छ.','yo|nepali|यो;kitab|nepali|किताब;dherai|nepali|धेरै;ramro|nepali|राम्रो;cha|nepali|छ'),
('nepali','hami bholi ghar janchau.','हामी भोलि घर जान्छौँ.','hami|nepali|हामी;bholi|nepali|भोलि;ghar|nepali|घर;janchau|nepali|जान्छौँ,जान्छौं'),
('nepali','usle mitho khana banayo.','उसले मिठो खाना बनायो.','usle|nepali|उसले;mitho|nepali|मिठो;khana|nepali|खाना;banayo|nepali|बनायो'),
('nepali','malai naya luga chahinchha.','मलाई नयाँ लुगा चाहिन्छ.','malai|nepali|मलाई;naya|nepali|नयाँ;luga|nepali|लुगा;chahinchha|nepali|चाहिन्छ'),
('nepali','aama bazar janu bhayo.','आमा बजार जानु भयो.','aama|nepali|आमा;bazar|nepali|बजार;janu|nepali|जानु;bhayo|nepali|भयो'),
('nepali','sathi sanga kura gare.','साथी संग कुरा गरे.','sathi|nepali|साथी;sanga|nepali|संग,सँग;kura|nepali|कुरा;gare|nepali|गरे'),
('nepali','yo bato kaha jancha?','यो बाटो कहाँ जान्छ?','yo|nepali|यो;bato|nepali|बाटो;kaha|nepali|कहाँ;jancha|nepali|जान्छ'),
('nepali','baccha haru bahira kheldai chan.','बच्चा हरु बाहिर खेल्दै छन्.','baccha|nepali|बच्चा;haru|nepali|हरु,हरू;bahira|nepali|बाहिर;kheldai|nepali|खेल्दै;chan|nepali|छन्'),
('mixed','bholi project sakera ghar janu.','भोलि project सकेर घर जानु.','bholi|nepali|भोलि;project|english|project;sakera|nepali|सकेर;ghar|nepali|घर;janu|nepali|जानु'),
('mixed','mero laptop aja dherai slow cha.','मेरो laptop आज धेरै slow छ.','mero|nepali|मेरो;laptop|english|laptop;aja|nepali|आज;dherai|nepali|धेरै;slow|english|slow;cha|nepali|छ'),
('mixed','please malai file pathaunu.','please मलाई file पठाउनु.','please|english|please;malai|nepali|मलाई;file|english|file;pathaunu|nepali|पठाउनु'),
('mixed','hami weekend ma park janchau.','हामी weekend मा park जान्छौँ.','hami|nepali|हामी;weekend|english|weekend;ma|nepali|मा;park|english|park;janchau|nepali|जान्छौँ,जान्छौं'),
('mixed','aaja office ko lunch mitho thiyo.','आज office को lunch मिठो थियो.','aaja|nepali|आज;office|english|office;ko|nepali|को;lunch|english|lunch;mitho|nepali|मिठो;thiyo|nepali|थियो'),
('mixed','timro meeting kati baje cha?','तिम्रो meeting कति बजे छ?','timro|nepali|तिम्रो;meeting|english|meeting;kati|nepali|कति;baje|nepali|बजे;cha|nepali|छ'),
('mixed','maile photos sabai download gare.','मैले photos सबै download गरे.','maile|nepali|मैले;photos|english|photos;sabai|nepali|सबै;download|english|download;gare|nepali|गरे'),
('mixed','yo message pachi call garnu.','यो message पछि call गर्नु.','yo|nepali|यो;message|english|message;pachi|nepali|पछि;call|english|call;garnu|nepali|गर्नु'),
('mixed','hamro team le game jityo.','हाम्रो team ले game जित्यो.','hamro|nepali|हाम्रो;team|english|team;le|nepali|ले;game|english|game;jityo|nepali|जित्यो'),
('mixed','aaja weather ekdam cold cha.','आज weather एकदम cold छ.','aaja|nepali|आज;weather|english|weather;ekdam|nepali|एकदम;cold|english|cold;cha|nepali|छ'),
('ambiguity','malai pani chahiyo.','मलाई पानी चाहियो.','malai|nepali|मलाई;pani|nepali|पानी;chahiyo|nepali|चाहियो'),
('ambiguity','ma pani aauchhu.','म पनि आउँछु.','ma|nepali|म;pani|nepali|पनि;aauchhu|nepali|आउँछु'),
('ambiguity','ma ghar ma chu.','म घर मा छु.','ma|nepali|म;ghar|nepali|घर;ma|nepali|मा;chu|nepali|छु'),
('ambiguity','the man opened the door.','the man opened the door.','the|english|the;man|english|man;opened|english|opened;door|english|door'),
('ambiguity','mero man khusi cha.','मेरो मन खुसी छ.','mero|nepali|मेरो;man|nepali|मन;khusi|nepali|खुसी,खुशी;cha|nepali|छ'),
('ambiguity','please write your name here.','please write your name here.','please|english|please;write|english|write;name|english|name;here|english|here'),
('ambiguity','timro naam ke ho?','तिम्रो नाम के हो?','timro|nepali|तिम्रो;naam|nepali|नाम;ke|nepali|के;ho|nepali|हो'),
('ambiguity','the bus stops near my home.','the bus stops near my home.','bus|english|bus;stops|english|stops;near|english|near;home|english|home'),
('ambiguity','hami bus ma janchau.','हामी bus मा जान्छौँ.','hami|nepali|हामी;bus|english|bus;ma|nepali|मा;janchau|nepali|जान्छौँ,जान्छौं'),
('ambiguity','this is a test.','this is a test.','this|english|this;is|english|is;a|english|a;test|english|test'),
('literal','visit https://example.com/path now','visit https://example.com/path now','visit|english|visit;https://example.com/path|literal|https://example.com/path;now|english|now'),
('literal','email test@example.org bholi','email test@example.org भोलि','email|english|email;test@example.org|literal|test@example.org;bholi|nepali|भोलि'),
('literal','yo file src/main.swift ma cha','यो file src/main.swift मा छ','yo|nepali|यो;file|english|file;src/main.swift|literal|src/main.swift;ma|nepali|मा;cha|nepali|छ'),
('literal','keep my_variable unchanged','keep my_variable unchanged','keep|english|keep;my_variable|literal|my_variable;unchanged|english|unchanged'),
('literal','run `git status` first','run `git status` first','run|english|run;`git status`|literal|`git status`;first|english|first'),
('literal','open config.json before lunch','open config.json before lunch','open|english|open;config.json|literal|config.json;before|english|before;lunch|english|lunch'),
('literal','send https://nepal.gov.np to me','send https://nepal.gov.np to me','send|english|send;https://nepal.gov.np|literal|https://nepal.gov.np;to|english|to;me|english|me'),
('literal','hello 👋 timi sanchai chau?','hello 👋 तिमी सन्चै छौ?','hello|english|hello;👋|literal|👋;timi|nepali|तिमी;sanchai|nepali|सन्चै,सञ्चै;chau|nepali|छौ'),
('literal','the ID is AB123 now','the ID is AB123 now','the|english|the;ID|literal|ID;is|english|is;AB123|literal|AB123;now|english|now'),
('literal','check camelCase before deploy','check camelCase before deploy','check|english|check;camelCase|literal|camelCase;before|english|before;deploy|english|deploy'),
]

cases=[]
for i,(category, source, expected, encoded) in enumerate(ROWS, 1):
    annotations=[]
    for entry in encoded.split(';'):
        token,role,alternatives=entry.split('|')
        assert token in source, (i,token)
        annotations.append({'token':token,'role':role,'acceptable':alternatives.split(',')})
    cases.append({'id':f'H{i:03}', 'category':category, 'split':'heldout', 'source':'synthetic',
                  'input':source, 'expected':[expected], 'annotations':annotations})
payload={'version':'2026-10-30-fresh-v1','description':'Fresh synthetic diagnostic, references unreviewed and not representative; frozen before running the engine.','cases':cases}
Path(__file__).with_name('corpus.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Wrote {len(cases)} cases')
