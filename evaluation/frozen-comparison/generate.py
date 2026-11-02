#!/usr/bin/env python3
"""Create frozen synthetic references only. Does not run NepType."""
import hashlib,json
from pathlib import Path

# Each row: category, input, accepted sentence output(s), selective ordered
# (input token/span, language role, accepted rendered alternatives).
rows = [
('english','We should reserve a table for Saturday.', ['We should reserve a table for Saturday.'], [('reserve','english',['reserve']),('table','english',['table']),('Saturday','english',['Saturday'])]),
('english','The children are playing outside today.', ['The children are playing outside today.'], [('children','english',['children']),('playing','english',['playing']),('outside','english',['outside'])]),
('english','She sent the revised document yesterday.', ['She sent the revised document yesterday.'], [('sent','english',['sent']),('revised','english',['revised']),('document','english',['document'])]),
('english','Can we move the appointment to Monday?', ['Can we move the appointment to Monday?'], [('move','english',['move']),('appointment','english',['appointment']),('Monday','english',['Monday'])]),
('english','My sister bought a blue bicycle.', ['My sister bought a blue bicycle.'], [('sister','english',['sister']),('blue','english',['blue']),('bicycle','english',['bicycle'])]),
('english','The bus leaves at seven in the morning.', ['The bus leaves at seven in the morning.'], [('bus','english',['bus']),('leaves','english',['leaves']),('morning','english',['morning'])]),
('english','Please remember to charge your laptop.', ['Please remember to charge your laptop.'], [('remember','english',['remember']),('charge','english',['charge']),('laptop','english',['laptop'])]),
('english','These photos look much better now.', ['These photos look much better now.'], [('photos','english',['photos']),('better','english',['better']),('now','english',['now'])]),
('english','I will call you after the movie ends.', ['I will call you after the movie ends.'], [('call','english',['call']),('movie','english',['movie']),('ends','english',['ends'])]),
('english','Their garden has beautiful yellow flowers.', ['Their garden has beautiful yellow flowers.'], [('garden','english',['garden']),('yellow','english',['yellow']),('flowers','english',['flowers'])]),
('english','Could you check the address again?', ['Could you check the address again?'], [('check','english',['check']),('address','english',['address']),('again','english',['again'])]),
('english','We have enough time to finish this.', ['We have enough time to finish this.'], [('enough','english',['enough']),('time','english',['time']),('finish','english',['finish'])]),
('nepali','aaja bihana dherai chiso thiyo.', ['आज बिहान धेरै चिसो थियो।','आज बिहान धेरै चिसो थियो.'], [('aaja','nepali',['आज']),('bihana','nepali',['बिहान']),('dherai','nepali',['धेरै']),('chiso','nepali',['चिसो']),('thiyo','nepali',['थियो'])]),
('nepali','timilai yo geet man parchha?', ['तिमीलाई यो गीत मन पर्छ?'], [('timilai','nepali',['तिमीलाई']),('yo','nepali',['यो']),('geet','nepali',['गीत']),('man','nepali',['मन']),('parchha','nepali',['पर्छ'])]),
('nepali','bholi beluka ghar aaunu hola.', ['भोलि बेलुका घर आउनु होला।','भोलि बेलुका घर आउनु होला.'], [('bholi','nepali',['भोलि']),('beluka','nepali',['बेलुका']),('ghar','nepali',['घर']),('aaunu','nepali',['आउनु']),('hola','nepali',['होला'])]),
('nepali','hami sanga samaya kam cha.', ['हामीसँग समय कम छ।','हामी सँग समय कम छ.','हामी सँग समय कम छ।'], [('hami','nepali',['हामी']),('sanga','nepali',['सँग','संग']),('samaya','nepali',['समय']),('kam','nepali',['कम']),('cha','nepali',['छ'])]),
('nepali','usle naya kitab kineko cha.', ['उसले नयाँ किताब किनेको छ।','उसले नयाँ किताब किनेको छ.'], [('usle','nepali',['उसले']),('naya','nepali',['नयाँ']),('kitab','nepali',['किताब']),('kineko','nepali',['किनेको']),('cha','nepali',['छ'])]),
('nepali','yo bato kata jancha?', ['यो बाटो कता जान्छ?'], [('yo','nepali',['यो']),('bato','nepali',['बाटो']),('kata','nepali',['कता']),('jancha','nepali',['जान्छ'])]),
('nepali','malai ek cup chiya dinu na.', ['मलाई एक cup चिया दिनु न।','मलाई एक cup चिया दिनु न.','मलाई एक कप चिया दिनु न।'], [('malai','nepali',['मलाई']),('ek','nepali',['एक']),('cup','english',['cup','कप']),('chiya','nepali',['चिया']),('dinu','nepali',['दिनु']),('na','nepali',['न'])]),
('nepali','aama le mitho khana banaunu bhayo.', ['आमाले मिठो खाना बनाउनु भयो।','आमा ले मिठो खाना बनाउनु भयो.','आमा ले मिठो खाना बनाउनु भयो।'], [('aama','nepali',['आमा']),('le','nepali',['ले']),('mitho','nepali',['मिठो','मीठो']),('khana','nepali',['खाना']),('banaunu','nepali',['बनाउनु']),('bhayo','nepali',['भयो'])]),
('nepali','sabai jana bistaarai hidnu hos.', ['सबै जना बिस्तारै हिँड्नुहोस्।','सबै जना बिस्तारै हिँड्नु होस्.','सबै जना बिस्तारै हिँड्नु होस्।'], [('sabai','nepali',['सबै']),('jana','nepali',['जना']),('bistaarai','nepali',['बिस्तारै']),('hidnu','nepali',['हिँड्नु','हिंड्नु']),('hos','nepali',['होस्'])]),
('nepali','timi kahile farkinchau?', ['तिमी कहिले फर्किन्छौ?'], [('timi','nepali',['तिमी']),('kahile','nepali',['कहिले']),('farkinchau','nepali',['फर्किन्छौ'])]),
('nepali','maile chithi hijo pathaeko thiye.', ['मैले चिठी हिजो पठाएको थिएँ।','मैले चिठी हिजो पठाएको थिएँ.'], [('maile','nepali',['मैले']),('chithi','nepali',['चिठी','चिट्ठी']),('hijo','nepali',['हिजो']),('pathaeko','nepali',['पठाएको']),('thiye','nepali',['थिएँ'])]),
('nepali','hamro ghar najikai euta pasal cha.', ['हाम्रो घर नजिकै एउटा पसल छ।','हाम्रो घर नजिकै एउटा पसल छ.'], [('hamro','nepali',['हाम्रो']),('ghar','nepali',['घर']),('najikai','nepali',['नजिकै']),('euta','nepali',['एउटा']),('pasal','nepali',['पसल']),('cha','nepali',['छ'])]),
('mixed','aaja meeting pachi ghar janchu.', ['आज meeting पछि घर जान्छु.','आज meeting पछि घर जान्छु।'], [('aaja','nepali',['आज']),('meeting','english',['meeting']),('pachi','nepali',['पछि']),('ghar','nepali',['घर']),('janchu','nepali',['जान्छु'])]),
('mixed','mero laptop ko screen bigriyo.', ['मेरो laptop को screen बिग्रियो.','मेरो laptop को screen बिग्रियो।'], [('mero','nepali',['मेरो']),('laptop','english',['laptop']),('ko','nepali',['को']),('screen','english',['screen']),('bigriyo','nepali',['बिग्रियो'])]),
('mixed','please yo file malai pathaideu.', ['please यो file मलाई पठाइदेऊ.','please यो file मलाई पठाइदेउ.'], [('please','english',['please']),('yo','nepali',['यो']),('file','english',['file']),('malai','nepali',['मलाई']),('pathaideu','nepali',['पठाइदेऊ','पठाइदेउ'])]),
('mixed','bholi office ma lunch khane ho?', ['भोलि office मा lunch खाने हो?'], [('bholi','nepali',['भोलि']),('office','english',['office']),('ma','nepali',['मा']),('lunch','english',['lunch']),('khane','nepali',['खाने']),('ho','nepali',['हो'])]),
('mixed','yo photo ekdam clear cha.', ['यो photo एकदम clear छ.','यो photo एकदम clear छ।'], [('yo','nepali',['यो']),('photo','english',['photo']),('ekdam','nepali',['एकदम']),('clear','english',['clear']),('cha','nepali',['छ'])]),
('mixed','hamro train 10 minute dhilo cha.', ['हाम्रो train 10 minute ढिलो छ.','हाम्रो train 10 minute ढिलो छ।'], [('hamro','nepali',['हाम्रो']),('train','english',['train']),('10','literal',['10']),('minute','english',['minute']),('dhilo','nepali',['ढिलो']),('cha','nepali',['छ'])]),
('mixed','malai address message gara na.', ['मलाई address message गर न.','मलाई address message गर न।'], [('malai','nepali',['मलाई']),('address','english',['address']),('message','english',['message']),('gara','nepali',['गर']),('na','nepali',['न'])]),
('mixed','website kholna internet chaincha.', ['website खोल्न internet चाहिन्छ.','website खोल्न internet चाहिन्छ।'], [('website','english',['website']),('kholna','nepali',['खोल्न']),('internet','english',['internet']),('chaincha','nepali',['चाहिन्छ'])]),
('mixed','maile ticket online book gare.', ['मैले ticket online book गरेँ.','मैले ticket online book गरे.','मैले ticket online book गरेँ।'], [('maile','nepali',['मैले']),('ticket','english',['ticket']),('online','english',['online']),('book','english',['book']),('gare','nepali',['गरेँ','गरे'])]),
('mixed','timro idea dherai ramro lagyo.', ['तिम्रो idea धेरै राम्रो लाग्यो.','तिम्रो idea धेरै राम्रो लाग्यो।'], [('timro','nepali',['तिम्रो']),('idea','english',['idea']),('dherai','nepali',['धेरै']),('ramro','nepali',['राम्रो']),('lagyo','nepali',['लाग्यो'])]),
('mixed','Sunday ma sathi sanga movie herne.', ['Sunday मा साथी सँग movie हेर्ने.','Sunday मा साथीसँग movie हेर्ने।'], [('Sunday','english',['Sunday']),('ma','nepali',['मा']),('sathi','nepali',['साथी']),('sanga','nepali',['सँग','संग']),('movie','english',['movie']),('herne','nepali',['हेर्ने'])]),
('mixed','phone silent ma rakha please.', ['phone silent मा राख please.','phone silent मा राख please।'], [('phone','english',['phone']),('silent','english',['silent']),('ma','nepali',['मा']),('rakha','nepali',['राख']),('please','english',['please'])]),
('ambiguity','ma pani aauchhu.', ['म पनि आउँछु.','म पनि आउँछु।'], [('ma','nepali',['म']),('pani','nepali',['पनि']),('aauchhu','nepali',['आउँछु'])]),
('ambiguity','pani ek glass dinu.', ['पानी एक glass दिनु.','पानी एक glass दिनु।'], [('pani','nepali',['पानी']),('ek','nepali',['एक']),('glass','english',['glass']),('dinu','nepali',['दिनु'])]),
('ambiguity','the man opened the door.', ['the man opened the door.'], [('the','english',['the']),('man','english',['man']),('opened','english',['opened']),('door','english',['door'])]),
('ambiguity','mero man aaja khusi cha.', ['मेरो मन आज खुसी छ.','मेरो मन आज खुशी छ.'], [('mero','nepali',['मेरो']),('man','nepali',['मन']),('aaja','nepali',['आज']),('khusi','nepali',['खुसी','खुशी']),('cha','nepali',['छ'])]),
('ambiguity','ma ghar ma baschu.', ['म घर मा बस्छु.','म घरमा बस्छु।','म घर मा बस्छु।'], [('ma','nepali',['म']),('ghar','nepali',['घर']),('ma','nepali',['मा']),('baschu','nepali',['बस्छु'])]),
('ambiguity','he can open the can.', ['he can open the can.'], [('he','english',['he']),('can','english',['can']),('open','english',['open']),('can','english',['can'])]),
('ambiguity','yo kura thik cha tara arko chaina.', ['यो कुरा ठीक छ तर अर्को छैन.','यो कुरा ठिक छ तर अर्को छैन।'], [('yo','nepali',['यो']),('kura','nepali',['कुरा']),('thik','nepali',['ठीक','ठिक']),('cha','nepali',['छ']),('tara','nepali',['तर']),('arko','nepali',['अर्को']),('chaina','nepali',['छैन'])]),
('ambiguity','tara is my friend.', ['tara is my friend.'], [('tara','english',['tara']),('is','english',['is']),('my','english',['my']),('friend','english',['friend'])]),
('ambiguity','ma cricket herna man parcha.', ['म cricket हेर्न मन पर्छ.','म क्रिकेट हेर्न मन पर्छ.'], [('ma','nepali',['म']),('cricket','english',['cricket','क्रिकेट']),('herna','nepali',['हेर्न']),('man','nepali',['मन']),('parcha','nepali',['पर्छ'])]),
('ambiguity','we will park near the park.', ['we will park near the park.'], [('we','english',['we']),('park','english',['park']),('near','english',['near']),('park','english',['park'])]),
('ambiguity','usko naam ram ho.', ['उसको नाम राम हो.','उसको नाम राम हो।'], [('usko','nepali',['उसको']),('naam','nepali',['नाम']),('ram','nepali',['राम']),('ho','nepali',['हो'])]),
('ambiguity','please call Ram tomorrow.', ['please call Ram tomorrow.'], [('please','english',['please']),('call','english',['call']),('Ram','english',['Ram']),('tomorrow','english',['tomorrow'])]),
('literal','Open https://example.org/a?x=2 now.', ['Open https://example.org/a?x=2 now.'], [('Open','english',['Open']),('https://example.org/a?x=2','literal',['https://example.org/a?x=2']),('now','english',['now'])]),
('literal','Email maya@example.org after lunch.', ['Email maya@example.org after lunch.'], [('Email','english',['Email']),('maya@example.org','literal',['maya@example.org']),('lunch','english',['lunch'])]),
('literal','Run `git status` before you commit.', ['Run `git status` before you commit.'], [('Run','english',['Run']),('`git status`','literal',['`git status`']),('commit','english',['commit'])]),
('literal','Save src/config.json before editing.', ['Save src/config.json before editing.'], [('Save','english',['Save']),('src/config.json','literal',['src/config.json']),('editing','english',['editing'])]),
('literal','Set user_name to the new value.', ['Set user_name to the new value.'], [('Set','english',['Set']),('user_name','literal',['user_name']),('value','english',['value'])]),
('literal','Open the file README.md today.', ['Open the file README.md today.'], [('file','english',['file']),('README.md','literal',['README.md']),('today','english',['today'])]),
('literal','Use orderId42 in the request.', ['Use orderId42 in the request.'], [('Use','english',['Use']),('orderId42','literal',['orderId42']),('request','english',['request'])]),
('literal','🙂 aaja ghar ma baschu.', ['🙂 आज घर मा बस्छु.','🙂 आज घरमा बस्छु।'], [('🙂','literal',['🙂']),('aaja','nepali',['आज']),('ghar','nepali',['घर']),('ma','nepali',['मा']),('baschu','nepali',['बस्छु'])]),
('literal','Visit www.example.org for details.', ['Visit www.example.org for details.'], [('Visit','english',['Visit']),('www.example.org','literal',['www.example.org']),('details','english',['details'])]),
('literal','Write `npm test` in the terminal.', ['Write `npm test` in the terminal.'], [('Write','english',['Write']),('`npm test`','literal',['`npm test`']),('terminal','english',['terminal'])]),
('literal','Set cost to 42 and retry.', ['Set cost to 42 and retry.'], [('cost','english',['cost']),('42','literal',['42']),('retry','english',['retry'])]),
('literal','Send the path docs/setup.md please.', ['Send the path docs/setup.md please.'], [('path','english',['path']),('docs/setup.md','literal',['docs/setup.md']),('please','english',['please'])]),
]
assert len(rows)==60
cases=[]
for index,(category,source,expected,annotations) in enumerate(rows,1):
    cursor=0; items=[]
    for token,role,acceptable in annotations:
        position=source.find(token,cursor)
        if position<0: raise ValueError((index,token,source))
        cursor=position+len(token)
        items.append({'token':token,'role':role,'acceptable':acceptable})
    cases.append({'id':f'F{index:03d}','category':category,'split':'heldout','source':'synthetic','input':source,'expected':expected,'annotations':items})
out={'version':'2026-10-30-frozen-v2','description':'Untouched synthetic probe, references unreviewed and not representative.','cases':cases}
path=Path(__file__).with_name('corpus.json')
path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('wrote',len(cases),'cases; sha256',hashlib.sha256(path.read_bytes()).hexdigest())
