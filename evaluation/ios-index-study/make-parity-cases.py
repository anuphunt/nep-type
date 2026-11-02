import json,sys,struct
from pathlib import Path
source=Path(sys.argv[1]);packed=Path(sys.argv[2]);out=Path(sys.argv[3]);data=packed.read_bytes(); count=struct.unpack_from('<I',data,4)[0];p=44;keys=[]
for _ in range(count):
 n=data[p];p+=1;keys.append(data[p:p+n].decode());p+=n+16
sample=set(keys); prior=None
with source.open('rb') as f:
 for i,row in enumerate(f):
  word=row.split(b'\t',1)[0].decode('ascii')
  if i%997==0 or word in sample:
   sample.add(word)
   if prior:sample.add(prior)
  prior=word
 if prior:sample.add(prior)
sample.update(['missingzzqxyz','a','z','not_a_key','नमस्ते'])
out.write_text(json.dumps(sorted(sample),ensure_ascii=False),encoding='utf-8')
print(len(sample))
