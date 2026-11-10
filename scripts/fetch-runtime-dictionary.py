#!/usr/bin/env python3
"""Recover the pinned native pack from the already published compiled web engine.

No raw dictionary exports are downloaded or committed. Both the web artifact and
the extracted runtime pack must match their independently pinned SHA-256 values.
"""
import gzip
import hashlib
import json
import shutil
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'engine/data/manifest.json').read_text())
source = json.loads((ROOT / 'engine/data/runtime-source.json').read_text())
pack = ROOT / 'engine/data/neptype.pack'
if not pack.exists() or hashlib.sha256(pack.read_bytes()).hexdigest() != manifest['sha256']:
    cache = ROOT / 'build/runtime-download'
    cache.mkdir(parents=True, exist_ok=True)
    compressed = cache / 'engine.wasm.gz'
    with urllib.request.urlopen(source['url'], timeout=120) as response, compressed.open('wb') as output:
        shutil.copyfileobj(response, output)
    assert hashlib.sha256(compressed.read_bytes()).hexdigest() == source['compressed_sha256'], 'Downloaded engine hash mismatch'
    wasm = gzip.decompress(compressed.read_bytes())
    assert len(wasm) == source['wasm_bytes']
    assert hashlib.sha256(wasm).hexdigest() == source['wasm_sha256'], 'WebAssembly hash mismatch'
    offset = source['pack_offset']
    data = wasm[offset:offset + manifest['bytes']]
    assert data.startswith(b'NEPTYPE3')
    assert hashlib.sha256(data).hexdigest() == manifest['sha256'], 'Native pack hash mismatch'
    pending = pack.with_suffix('.building')
    pending.write_bytes(data)
    pending.replace(pack)
provenance = ROOT / 'data/compiled/roman-nepali.manifest.json'
provenance.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(ROOT / 'engine/data/roman-nepali-provenance.json', provenance)
assert hashlib.sha256(provenance.read_bytes()).hexdigest() == manifest['sources']['data/compiled/roman-nepali.manifest.json']
print('Verified runtime dictionary:', manifest['id'])
