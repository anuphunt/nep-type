#!/usr/bin/env python3
"""Freeze the real native document/candidate contract used by Windows UI checks."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'shared/python'))
from neptype_engine import Engine

engine = Engine(sys.argv[1], ROOT / 'engine/data')
observations = []
try:
    assert engine.document('namaste')['output'] == 'नमस्ते'
    default = engine.document('pani')
    observations.append({'step': 'default_after_namaste', **default})
    assert default['output'] == 'पनि', default
    assert default['token'] == 'pani', default
    assert default['candidates'][:2] == ['पनि', 'पानी'] and 'pani' in default['candidates'], default
    selected = engine.document('pani', choice='पानी')
    observations.append({'step': 'alternative_selected', **selected})
    assert selected['output'] == 'पानी' and selected['output'] != default['output'], selected
    assert engine.document('pani')['output'] == 'पानी', 'Selected spelling did not persist'
    original = engine.document('pani', choice='pani')
    observations.append({'step': 'original_selected', **original})
    assert original['output'] == 'pani', original
    assert engine.document('pani')['output'] == 'pani', 'Original spelling did not persist'
finally:
    engine.close()

fresh = Engine(sys.argv[1], ROOT / 'engine/data')
try:
    assert fresh.document('pani')['output'] == 'पनि', 'Choice leaked into a fresh document'
finally:
    fresh.close()
print(json.dumps({'passed': True, 'observations': observations}, ensure_ascii=False))
