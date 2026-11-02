#!/usr/bin/env python3
"""Prevent independent production language engines and dictionary snapshots."""
import argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--ios-only',action='store_true');args=p.parse_args()
for name in ['Transliterator','Composer','InputSession','GeneratedAliasIndex','GeneratedIndexes']:
 s=(ROOT/'Sources/NepaliCore'/f'{name}.swift').read_text()
 for forbidden in ['NSRegularExpression','englishWords.contains','private static let lexicon','private static let english','func phonetic(_ input: String) -> String {\n']:
  assert forbidden not in s,(name,forbidden)
 assert not (ROOT/'platforms/ios/NepTypeKeyboard/SharedCore'/f'{name}.swift').exists(),name
project=(ROOT/'platforms/ios/NepTypeMobile.xcodeproj/project.pbxproj').read_text()
assert 'build-apple-engine.sh' in project and '-lneptype_engine' in project
assert 'path = ../../data/compiled/google-ne-aliases.tsv' not in project
assert 'path = ../../data/compiled/aksharantar-indiccorp-v1.tsv' not in project
if not args.ios_only:
 web=(ROOT/'landing-page/web-engine.mjs').read_text()
 assert 'new Worker' in web and 'phonetic' not in web and 'lexicon' not in web
 assert 'WebAssembly' not in (ROOT/'landing-page/web-tool.mjs').read_text(), 'UI must use the engine transport'
 for name in ['SortedCandidateIndex','CandidateMerger','PhoneticCandidates']:
  assert not (ROOT/'platforms/android/app/src/main/java/app/neptype/keyboard/core'/f'{name}.java').exists(),name
 assert not list((ROOT/'platforms/android/app/src/main/assets').glob('*.tsv'))
 assert not list((ROOT/'platforms/ios/NepTypeKeyboard/Resources').glob('*.tsv'))
print('All production frontends use the shared Rust engine and embedded dictionary')
