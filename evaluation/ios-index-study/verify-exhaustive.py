#!/usr/bin/env python3
"""Verify each packed source byte and every key/value row, without trusting hashes alone."""
import hashlib,struct,sys,zlib
from pathlib import Path
source=Path(sys.argv[1]); packed=Path(sys.argv[2]); data=packed.read_bytes()
assert data[:4]==b'LKI1'
blocks,rows=struct.unpack_from('<II',data,4); expected_sha=data[12:44]; cursor=44; entries=[]
for _ in range(blocks):
 n=data[cursor];cursor+=1;key=data[cursor:cursor+n];cursor+=n
 offset,compressed,raw=struct.unpack_from('<QII',data,cursor);cursor+=16
 entries.append((key,offset,compressed,raw))
hash_source=hashlib.sha256(); count=0; prev=b''
with source.open('rb') as stream:
 for key,offset,compressed,rawlen in entries:
  raw=zlib.decompress(data[cursor+offset:cursor+offset+compressed]); assert len(raw)==rawlen
  expected=stream.read(rawlen); assert raw==expected
  lines=raw.splitlines(keepends=True); assert lines and lines[0].split(b'\t',1)[0]==key
  for line in lines:
   assert line.endswith(b'\n'); k=line.split(b'\t',1)[0];assert not prev or prev<k;prev=k;count+=1
  hash_source.update(raw)
 assert stream.read()==b''
assert count==rows and hash_source.digest()==expected_sha
print(f'PASS {source.name}: {count} source rows / {source.stat().st_size} bytes match packed blocks exactly')
