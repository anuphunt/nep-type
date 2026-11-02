#!/usr/bin/env python3
"""Run the frozen behavior corpus through the real native C ABI on every host."""
import ctypes,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'shared/python'))
from neptype_engine import Engine
lib=ctypes.CDLL(str(Path(sys.argv[1]).resolve()))
lib.neptype_engine_query.argtypes=[ctypes.c_char_p];lib.neptype_engine_query.restype=ctypes.c_void_p
lib.neptype_string_destroy.argtypes=[ctypes.c_void_p]
count=0
for line in (ROOT/'shared/fixtures/swift-baseline.jsonl').read_text(encoding='utf8').splitlines():
 case=json.loads(line);raw=lib.neptype_engine_query(json.dumps(case['request'],ensure_ascii=False).encode('utf8'))
 assert raw
 try:actual=json.loads(ctypes.string_at(raw))
 finally:lib.neptype_string_destroy(raw)
 if case['request']['op']=='session':actual={'trace':actual['trace']}
 assert actual==case['expected'],case['request'];count+=1
engine=Engine(sys.argv[1],ROOT/'engine/data')
assert engine.dictionary_id==json.loads((ROOT/'engine/data/manifest.json').read_text())['id']
assert engine.document('ma pani',caret=6,choice='पानी')['output']=='म पानी'
assert engine.document('👋 ma pani',caret=8)['output']=='👋 म पानी'
engine.close()
print('PASS:',count,'frozen cases through native C ABI; identical dictionary fingerprint and correction mapping')
