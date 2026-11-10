#!/usr/bin/env python3
"""Reject native platform libraries built with a different dictionary."""
import argparse, ctypes, hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('libraries',nargs='+',type=Path)
p.add_argument('--cross-compiled',action='store_true',help='Verify builder receipts when this host cannot load the target ABI')
a=p.parse_args();expected=json.loads((ROOT/'engine/data/manifest.json').read_text())['id']
for library in a.libraries:
    if a.cross_compiled:
        receipt=json.loads(library.with_name('dictionary-build.json').read_text())
        h=hashlib.sha256()
        with library.open('rb') as f:
            for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
        assert receipt['library_sha256']==h.hexdigest(),f'Stale library receipt: {library}'
        actual=receipt['dictionary_id']
    else:
        lib=ctypes.CDLL(str(library.resolve()))
        lib.neptype_dictionary_id.restype=ctypes.c_char_p
        actual=lib.neptype_dictionary_id().decode('ascii')
    assert actual==expected,f'Rebuild {library}: dictionary {actual} does not match {expected}'
    print('Verified embedded dictionary:',library,expected)
