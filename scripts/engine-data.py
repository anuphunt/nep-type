#!/usr/bin/env python3
"""Verify one embedded Rust dictionary pack; stage identity and attribution only."""
import argparse, hashlib, json, shutil, subprocess, sys, os
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
 if manifest.get('schema')!=3 or manifest.get('dictionary')!='roman-nepali-v2-pilot-v1':
  raise SystemExit('The app requires the standalone Roman Nepali dictionary; run engine-data.py refresh')
 # A clean source checkout intentionally excludes the private alias exports.
 # Fetch the independently hashed compiled runtime in that case; local data
 # authoring still validates every available source and refresh needs exports.
 raw_sources = ('data/compiled/roman-nepali-intentional.tsv.gz', 'data/compiled/roman-nepali-typos.tsv.gz', 'data/compiled/roman-nepali-reviewed.json')
 missing = [name for name in raw_sources if not (ROOT/name).exists()]
 pack_only = os.environ.get('NEPTYPE_PACK_ONLY') == '1' or len(missing) == len(raw_sources)
 if missing and not pack_only:
  raise SystemExit('Incomplete dictionary exports; restore all source files or explicitly use NEPTYPE_PACK_ONLY=1')
 if pack_only and not PACK.exists():
  subprocess.run([sys.executable,str(ROOT/'scripts/fetch-runtime-dictionary.py')],check=True)
 for name,expected in manifest['sources'].items():
  if pack_only and not (ROOT/name).exists() and name in raw_sources:
   continue
  if digest(ROOT/name)!=expected: raise SystemExit('Dictionary source changed; review and run scripts/engine-data.py refresh: '+name)
 if not PACK.exists():
  if pack_only: raise SystemExit('Verified runtime download did not produce the dictionary pack')
  subprocess.run([sys.executable,str(ROOT/'scripts/build-dictionary-pack.py')],check=True,stdout=subprocess.DEVNULL)
  if json.loads(MANIFEST.read_text())!=manifest: raise SystemExit('Regenerated dictionary does not match the pinned manifest')
 if digest(PACK)!=manifest['sha256']: raise SystemExit('Dictionary pack does not match its pinned fingerprint')
 if args.command=='stage':
  if not args.destination: parser.error('stage needs a destination')
  out=Path(args.destination);out.mkdir(parents=True,exist_ok=True)
  # Remove obsolete platform snapshots from earlier builds. The current data
  # lives only inside the shared engine, never in these legacy TSV resources.
  for name in ['google-ne-aliases.tsv','google-ne-lexicon.tsv','aksharantar-indiccorp-v1.tsv','aksharantar-indiccorp-v1.manifest.json','nepali-authored-v1.json','nepali-authored-v1.tsv','AKSHARANTAR-PROVENANCE.json']:
   (out/name).unlink(missing_ok=True)
   (out/'Licenses'/name).unlink(missing_ok=True)
  (out/'neptype-dictionaries.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
  shutil.copyfile(ROOT/'data/compiled/roman-nepali.manifest.json',out/'ROMAN-NEPALI-PROVENANCE.json')
  shutil.copyfile(ROOT/'engine/data/RUST-LICENSES.txt',out/'RUST-LICENSES.txt')
  for name in ['CMUDICT-LICENSE.txt','GOOGLE-NE-ATTRIBUTION.txt','AKSHARANTAR-ATTRIBUTION.txt']: shutil.copyfile(ROOT/'data/sources'/name,out/name)
 print('Embedded dictionary:',manifest['id'])
if __name__=='__main__':main()
