#!/usr/bin/env python3
"""Lossless v3 pack of the standalone Roman dictionary; no legacy Nepali input."""
import gzip, hashlib, json, os, re, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'engine/data'
SOURCES=['data/compiled/roman-nepali-intentional.tsv.gz','data/compiled/roman-nepali-typos.tsv.gz']
def u32(v):return struct.pack('<I',v)
def vint(v):
    result=bytearray()
    while v>=128:result.append((v&127)|128);v>>=7
    result.append(v);return result
def digest(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
    return h.hexdigest()
def prefix_length(a,b):
    n=0
    while n<min(len(a),len(b)) and a[n]==b[n]:n+=1
    return n
def main():
    provenance=json.loads((ROOT/'data/compiled/roman-nepali.manifest.json').read_text())
    for name,entry in provenance['files'].items():
        assert digest(ROOT/'data/compiled'/name)==entry['sha256'],name
    spellings=set()
    for filename in SOURCES:
        with gzip.open(ROOT/filename,'rb') as f:
            for row in f:spellings.update(row.rstrip(b'\n').split(b'\t')[1:])
    pool=bytearray();pool_blocks=[];identifiers={};previous=b''
    for i,value in enumerate(sorted(spellings)):
        value.decode('utf8')
        identifiers[value]=i
        if i%32==0:pool_blocks.append(len(pool));prefix=0
        else:prefix=prefix_length(previous,value)
        suffix=value[prefix:];pool.extend(vint(prefix));pool.extend(vint(len(suffix)));pool.extend(suffix);previous=value
    del spellings
    def dictionary(filename):
        data=bytearray();blocks=[];previous=b'';count=0;pairs=0
        with gzip.open(ROOT/filename,'rb') as f:
            for count,row in enumerate(f,1):
                assert row.endswith(b'\n'),'Unterminated dictionary row'
                key,*values=row[:-1].split(b'\t')
                assert re.fullmatch(b'[a-z]+',key) and values and len(set(values))==len(values),'Invalid row'
                assert not previous or key>previous,'Unsorted dictionary'
                if (count-1)%64==0:blocks.append(len(data));prefix=0
                else:prefix=prefix_length(previous,key)
                suffix=key[prefix:];data.extend(vint(prefix));data.extend(vint(len(suffix)));data.extend(suffix)
                data.extend(vint(len(values)))
                for value in values:data.extend(vint(identifiers[value]))
                previous=key;pairs+=len(values)
        return u32(len(blocks))+b''.join(map(u32,blocks))+data,count,pairs
    intentional,intentional_count,intentional_pairs=dictionary(SOURCES[0])
    typos,typo_count,typo_pairs=dictionary(SOURCES[1])
    cmu=ROOT/'data/sources/cmudict.dict'
    assert digest(cmu)=='81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22'
    english=sorted({word for line in cmu.read_text().splitlines() if re.fullmatch('[a-z]+',word:=re.sub(r'\(\d+\)$','',line.split(' ',1)[0]))})
    meta={'lexicon':json.loads((ROOT/'data/compiled/roman-nepali-reviewed.json').read_text()),'common':json.loads((ROOT/'data/sources/english-common-v1.json').read_text())}
    # Preserve section layout for native/WASM readers; v3 uses UTF-8 pool and
    # variable-length lengths/counts so long words and collisions are not clipped.
    parts=[json.dumps(meta,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode(),('\n'.join(english)+'\n').encode(),u32(len(identifiers))+u32(len(pool_blocks))+b''.join(map(u32,pool_blocks))+pool,typos,intentional]
    payload=b''.join(u32(len(p))+p for p in parts);identity=hashlib.sha256(payload).digest();pack=b'NEPTYPE3'+identity+payload
    target=OUT/'neptype.pack';temporary=target.with_name(target.name+f'.{os.getpid()}.staging');temporary.write_bytes(pack);temporary.replace(target)
    sources=SOURCES+['data/compiled/roman-nepali-reviewed.json','data/compiled/roman-nepali.manifest.json','data/sources/english-common-v1.json','data/sources/cmudict.dict']
    manifest={'schema':3,'dictionary':'roman-nepali-v2-pilot-v1','id':identity.hex(),'sha256':hashlib.sha256(pack).hexdigest(),'bytes':len(pack),'english_words':len(english),'reviewed_keys':len(meta['lexicon']),'intentional_rows':intentional_count,'intentional_pairs':intentional_pairs,'typo_rows':typo_count,'typo_pairs':typo_pairs,'unique_spellings':len(identifiers),'source_database_sha256':provenance['source_database_sha256'],'pilot_approved':provenance['pilot_approved'],'pilot_held_suppressed':provenance['pilot_held_suppressed'],'sources':{s:digest(ROOT/s) for s in sources}}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n');print(json.dumps(manifest))
if __name__=='__main__':main()
