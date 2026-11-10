"""Check the new dictionary through the actual native ABI, including corrections."""
import ctypes
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'shared/python'))
from neptype_engine import Engine

library = sys.argv[1]
manifest = json.loads((ROOT / 'engine/data/manifest.json').read_text())
engine = Engine(library, ROOT / 'engine/data')
other = Engine(library, ROOT / 'engine/data')
try:
    assert engine.dictionary_id == manifest['id']
    for word in ['euta', 'eauta', 'yeuta', 'yauta']:
        assert engine.candidates(word, 0)[0] == 'एउटा'
    assert engine.document('namaste')['output'] == 'नमस्ते'
    assert engine.document('pani')['output'] == 'पनि'
    assert engine.document('pani', choice='पानी')['output'] == 'पानी'
    assert engine.document('👋 pani', caret=6)['output'] == '👋 पानी'
    assert other.document('pani')['output'] == 'पनि'
    assert engine.document('pani', choice='pani')['output'] == 'pani'
    literal = 'hello 🙂 https://example.com foo_bar'
    assert engine.document(literal, mode=1)['output'] == literal
finally:
    engine.close()
    other.close()
print(json.dumps({'passed': True, 'dictionary_id': manifest['id'], 'scope': 'Native ABI, spellings, correction mapping, Unicode and independent document handles'}))
