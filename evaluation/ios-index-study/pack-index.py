#!/usr/bin/env python3
"""Losslessly pack sorted UTF-8 TSV into independently zlib-compressed blocks."""
import argparse, hashlib, json, struct, zlib
from pathlib import Path
MAGIC = b'LKI1'
BLOCK_BYTES = 65536

def pack(source, destination):
    rows = []; payload = bytearray(); directory = []; digest = hashlib.sha256()
    previous = b''; count = 0
    def flush():
        nonlocal rows
        if not rows: return
        raw = b''.join(rows); data = zlib.compress(raw, level=6)
        directory.append((rows[0].split(b'\t',1)[0],len(payload),len(data),len(raw)))
        payload.extend(data); rows=[]
    size=0
    with source.open('rb') as handle:
        for row in handle:
            if not row.endswith(b'\n') or b'\t' not in row: raise ValueError('invalid TSV line')
            key=row.split(b'\t',1)[0]
            if not key or not all(97 <= c <= 122 for c in key) or (count and key <= previous): raise ValueError('keys not strictly byte sorted')
            if len(row) > BLOCK_BYTES: raise ValueError('line too large')
            digest.update(row); count+=1; previous=key
            if size + len(row) > BLOCK_BYTES and rows: flush(); size=0
            rows.append(row);size+=len(row)
        flush()
    header=bytearray(MAGIC+struct.pack('<II', len(directory), count)+digest.digest())
    for key,offset,compressed,raw in directory:
        if len(key)>255: raise ValueError('key too long')
        header+=struct.pack('<B',len(key))+key+struct.pack('<QII',offset,compressed,raw)
    destination.write_bytes(header+payload)
    return {'source':source.name,'raw_bytes':source.stat().st_size,'packed_bytes':destination.stat().st_size,'rows':count,'blocks':len(directory),'source_sha256':digest.hexdigest(),'packed_sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('source',type=Path);a.add_argument('destination',type=Path);args=a.parse_args()
    print(json.dumps(pack(args.source,args.destination),indent=2,sort_keys=True))
