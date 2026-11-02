#!/usr/bin/env python3
"""Lossless, deterministic pack: shared strings + front-coded blocks, no ranking changes."""
import hashlib, json, re, struct, os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'engine/data'
def u32(value): return struct.pack('<I', value)
def vint(value):
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128); value >>= 7
    result.append(value)
    return result
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pool, pool_blocks = bytearray(), []
    spellings = set()
    for filename in ['data/compiled/google-ne-aliases.tsv','data/compiled/aksharantar-indiccorp-v1.tsv']:
        with (ROOT/filename).open('rb') as stream:
            for row in stream: spellings.update(row.rstrip(b'\n').split(b'\t')[1:])
    identifiers = {}
    previous = b''
    for identifier, value in enumerate(sorted(spellings)):
        identifiers[value] = identifier
        # Every source spelling is Devanagari plus the two join controls.
        encoded = bytes(ord(c)-0x900 if ord(c)<0x980 else 128+(ord(c)-0x200c) for c in value.decode('utf8'))
        prefix = 0
        if identifier % 32 == 0: pool_blocks.append(len(pool))
        else:
            while prefix < min(len(previous),len(encoded)) and previous[prefix] == encoded[prefix]: prefix += 1
        suffix = encoded[prefix:]
        pool.extend(bytes([prefix,len(suffix)])); pool.extend(suffix); previous=encoded
    del spellings
    def intern(value): return identifiers[value]
    def dictionary(filename):
        data, blocks, previous = bytearray(), [], b''
        count = 0
        with (ROOT/filename).open('rb') as stream:
            for count, row in enumerate(stream, 1):
                if not row.endswith(b'\n'): raise ValueError('Unterminated dictionary row')
                key, *values = row[:-1].split(b'\t')
                if not re.fullmatch(b'[a-z]+', key) or not values or len(values)>64: raise ValueError('Invalid row')
                if previous and key <= previous: raise ValueError('Unsorted dictionary')
                prefix = 0
                if (count-1) % 64 == 0: blocks.append(len(data))
                else:
                    while prefix < min(len(previous),len(key),255) and previous[prefix] == key[prefix]: prefix += 1
                suffix = key[prefix:]
                if len(suffix)>255: raise ValueError('Oversized key')
                data.extend(bytes([prefix,len(suffix)])); data.extend(suffix); data.append(len(values))
                for value in values:
                    text=value.decode('utf8')
                    if not text or len(text)>60 or not all(0x900<=ord(c)<=0x97f or ord(c) in (0x200c,0x200d) for c in text): raise ValueError('Invalid candidate')
                    data.extend(vint(intern(value)))
                previous=key
        return u32(len(blocks))+b''.join(map(u32,blocks))+data, count
    aliases, alias_count = dictionary('data/compiled/google-ne-aliases.tsv')
    aksharantar, aksh_count = dictionary('data/compiled/aksharantar-indiccorp-v1.tsv')
    cmu = ROOT/'data/sources/cmudict.dict'
    if hashlib.sha256(cmu.read_bytes()).hexdigest() != '81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22': raise ValueError('CMU source changed')
    english = sorted({word for line in cmu.read_text(encoding='utf8').splitlines() if re.fullmatch('[a-z]+',word:=re.sub(r'\(\d+\)$','',line.split(' ',1)[0]))})
    meta = {'lexicon':json.loads((ROOT/'data/sources/nepali-authored-v1.json').read_text(encoding='utf8')),'common':json.loads((ROOT/'data/sources/english-common-v1.json').read_text(encoding='utf8'))}
    parts = [json.dumps(meta,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode(), ('\n'.join(english)+'\n').encode(),u32(len(identifiers))+u32(len(pool_blocks))+b''.join(map(u32,pool_blocks))+pool,aliases,aksharantar]
    payload=b''.join(u32(len(part))+part for part in parts)
    digest=hashlib.sha256(payload).digest()
    pack=b'NEPTYPE2'+digest+payload
    target=OUT/'neptype.pack'
    if not target.exists() or target.read_bytes()!=pack:
        temporary=target.with_name(target.name+f'.{os.getpid()}.staging');temporary.write_bytes(pack);temporary.replace(target)
    sources=['data/sources/nepali-authored-v1.json','data/sources/english-common-v1.json','data/sources/cmudict.dict','data/compiled/google-ne-aliases.tsv','data/compiled/aksharantar-indiccorp-v1.tsv']
    manifest={'schema':2,'id':digest.hex(),'sha256':hashlib.sha256(pack).hexdigest(),'bytes':len(pack),'english_words':len(english),'authored_words':len(meta['lexicon']),'alias_rows':alias_count,'aksharantar_rows':aksh_count,'unique_spellings':len(identifiers),'sources':{s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in sources}}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    print(json.dumps(manifest))
if __name__=='__main__': main()
