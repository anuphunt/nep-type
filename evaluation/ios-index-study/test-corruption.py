#!/usr/bin/env python3
import subprocess,tempfile,struct,sys
from pathlib import Path
root=Path(sys.argv[1]); exe=sys.argv[2]
with tempfile.TemporaryDirectory(prefix='neptype-packed-corrupt-') as folder:
 p=Path(folder);source=p/'source.tsv';source.write_text('hello\tनमस्ते\n',encoding='utf8');good=p/'good.lki'
 subprocess.run(['python3',str(root/'pack-index.py'),str(source),str(good)],check=True,capture_output=True)
 data=good.read_bytes();cases=[]
 def emit(name,raw,kind,key='hello'):
  f=p/name;f.write_bytes(raw);subprocess.run([exe,str(f),kind,key],check=True,capture_output=True);cases.append(name)
 emit('bad-magic',b'BAD!'+data[4:],'invalid')
 emit('oversized-directory',data[:4]+struct.pack('<I',100001)+data[8:],'invalid')
 emit('truncated',data[:-1],'invalid')
 emit('bad-block',data[:-1]+bytes([data[-1]^0xff]),'empty')
 for name,value in [('ascii','hello\tASCII\n'),('empty','hello\t\n'),('long','hello\t'+'अ'*61+'\n'),('too-many','hello\t'+'\t'.join(['अ']*65)+'\n')]:
  source.write_text(value,encoding='utf8');subprocess.run(['python3',str(root/'pack-index.py'),str(source),str(good)],check=True,capture_output=True);emit(name,good.read_bytes(),'empty')
 source.write_bytes(b'hello\t\xff\n');subprocess.run(['python3',str(root/'pack-index.py'),str(source),str(good)],check=True,capture_output=True);emit('invalid-utf8',good.read_bytes(),'empty')
 source.write_bytes(b'hello\t'+('अ'*1400).encode()+b'\n');subprocess.run(['python3',str(root/'pack-index.py'),str(source),str(good)],check=True,capture_output=True);emit('oversized-row',good.read_bytes(),'empty')
 source.write_bytes(b'hello\t'+('म').encode())
 failed=subprocess.run(['python3',str(root/'pack-index.py'),str(source),str(good)],capture_output=True)
 assert failed.returncode != 0; cases.append('builder-refuses-unterminated')
print('PASS: '+', '.join(cases))
