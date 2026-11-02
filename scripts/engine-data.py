#!/usr/bin/env python3
"""Verify one embedded Rust dictionary pack; stage identity and attribution only."""
import argparse, hashlib, json, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'engine/data/neptype.pack'
MANIFEST=ROOT/'engine/data/manifest.json'
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as stream:
  for part in iter(lambda:stream.read(1024*1024),b''): h.update(part)
 return h.hexdigest()
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('command',choices=['refresh','check','stage']);parser.add_argument('destination',nargs='?');args=parser.parse_args()
 manifest=json.loads(MANIFEST.read_text())
 if args.command=='refresh':
  subprocess.run([sys.executable,str(ROOT/'scripts/build-dictionary-pack.py')],check=True,stdout=subprocess.DEVNULL)
  manifest=json.loads(MANIFEST.read_text())
 for name,expected in manifest['sources'].items():
  if digest(ROOT/name)!=expected: raise SystemExit('Dictionary source changed; review and run scripts/engine-data.py refresh: '+name)
 if not PACK.exists():
  subprocess.run([sys.executable,str(ROOT/'scripts/build-dictionary-pack.py')],check=True,stdout=subprocess.DEVNULL)
  if json.loads(MANIFEST.read_text())!=manifest: raise SystemExit('Regenerated dictionary does not match the pinned manifest')
 if digest(PACK)!=manifest['sha256']: raise SystemExit('Dictionary pack does not match its pinned fingerprint')
 if args.command=='stage':
  if not args.destination: parser.error('stage needs a destination')
  out=Path(args.destination);out.mkdir(parents=True,exist_ok=True)
  (out/'neptype-dictionaries.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
  shutil.copyfile(ROOT/'engine/data/RUST-LICENSES.txt',out/'RUST-LICENSES.txt')
  for name in ['CMUDICT-LICENSE.txt','GOOGLE-NE-ATTRIBUTION.txt','AKSHARANTAR-ATTRIBUTION.txt']: shutil.copyfile(ROOT/'data/sources'/name,out/name)
 print('Embedded dictionary:',manifest['id'])
if __name__=='__main__':main()
