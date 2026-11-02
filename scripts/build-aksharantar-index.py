#!/usr/bin/env python3
"""Build a tagged IndicCorp index from a pinned archive for local evaluation.

Usage: python3 scripts/build-aksharantar-index.py /path/to/nep.zip
Commercial licensing must be resolved before distribution. No model score or count is used for ranking.
"""
import collections, hashlib, json, pathlib, re, sqlite3, sys, tempfile, zipfile
root=pathlib.Path(__file__).resolve().parent.parent
if len(sys.argv)!=2: raise SystemExit(__doc__)
archive=pathlib.Path(sys.argv[1]); sha='8bdcc5957d701ea36b63c00c713b43bc30902774b70736737d480e77929de92c'
if hashlib.sha256(archive.read_bytes()).hexdigest()!=sha: raise SystemExit('Archive SHA-256 mismatch')
out=root/'data/compiled/aksharantar-indiccorp-v1.tsv';out.parent.mkdir(parents=True,exist_ok=True)
counts=collections.Counter()
with tempfile.TemporaryDirectory(prefix='lekha-aksh-') as tmp:
 db=sqlite3.connect(str(pathlib.Path(tmp)/'pairs.sqlite'))
 db.execute('PRAGMA journal_mode=OFF');db.execute('PRAGMA synchronous=OFF')
 db.execute('CREATE TABLE pairs (roman TEXT NOT NULL, native TEXT NOT NULL, PRIMARY KEY(roman,native)) WITHOUT ROWID')
 with zipfile.ZipFile(archive) as z, z.open('nep_train.json') as f:
  batch=[]
  for line in f:
   row=json.loads(line); counts['train_rows']+=1
   source=row.get('source')
   if source!='IndicCorp':counts['excluded_other_source']+=1;continue
   counts['indiccorp_rows']+=1
   roman=row.get('english word',''); native=row.get('native word','')
   if not re.fullmatch('[a-z]{2,35}',roman) or not re.fullmatch('[\u0900-\u097f\u200c\u200d]{1,60}',native): counts['excluded_bad_shape']+=1;continue
   batch.append((roman,native))
   if len(batch)>=10000:db.executemany('INSERT OR IGNORE INTO pairs VALUES (?,?)',batch);batch=[]
  if batch: db.executemany('INSERT OR IGNORE INTO pairs VALUES (?,?)',batch)
  db.commit()
 counts['distinct_pairs']=db.execute('SELECT COUNT(*) FROM pairs').fetchone()[0]
 temporary=out.with_suffix('.tsv.tmp')
 with temporary.open('w',encoding='utf-8') as f:
  key=None;values=[]
  def flush():
   if key is not None:
    f.write(key+'\t'+'\t'.join(values)+'\n')
    counts['keys']+=1
    if len(values)>1:counts['collision_keys']+=1
    counts['max_candidates']=max(counts['max_candidates'],len(values))
  for roman,native in db.execute('SELECT roman,native FROM pairs ORDER BY roman,native'):
   if roman!=key:flush();key=roman;values=[]
   values.append(native)
  flush()
 temporary.replace(out)
 manifest={'commercial_rights_review_pending':True,'release_blocker':'Commercial redistribution rights and underlying source provenance unresolved. User will resolve before distribution.', 'source':'AI4Bharat Aksharantar Nepali train / IndicCorp-labeled rows only','source_revision':'e418c1fc928d9f5393af33268472cf20c1891be8','source_url':'https://huggingface.co/datasets/ai4bharat/Aksharantar/blob/e418c1fc928d9f5393af33268472cf20c1891be8/README.md','archive_sha256':sha,'source_tag':'IndicCorp','transformation':'ASCII lowercase roman 2–35 chars and Devanagari 1–60 chars; sorted unique pairs; other source tags excluded. Lexical order is not ranking. Model score is discarded.','counts':dict(counts),'index_bytes':out.stat().st_size,'index_sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
 (out.parent/'aksharantar-indiccorp-v1.manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
 print(json.dumps(manifest,indent=2,ensure_ascii=False))
