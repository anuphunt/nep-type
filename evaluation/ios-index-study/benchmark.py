#!/usr/bin/env python3
"""macOS process benchmark; filesystem cache is not cleared; no iOS host."""
import json,os,re,statistics,subprocess,sys
exe,tsv,lki=sys.argv[1:]
report={}
for mode in ('raw','packed'):
 values=[]
 for _ in range(10):
  env=dict(os.environ,NEPTYPE_AKSHARANTAR_INDEX=tsv)
  p=subprocess.run(['/usr/bin/time','-l',exe,mode,lki],capture_output=True,text=True,check=True,env=env)
  row=json.loads(p.stdout);match=re.search(r'^\s*(\d+)\s+maximum resident set size',p.stderr,re.M)
  if not match:raise RuntimeError('memory statistic unavailable')
  row['max_rss_bytes']=int(match.group(1));values.append(row)
 report[mode]={'runs':values,'median_init_plus_first_ms':statistics.median(r['init_plus_first_ms'] for r in values),'median_first_ms':statistics.median(r['first_ms'] for r in values),'median_warm_p50_ms':statistics.median(r['warm_p50_ms'] for r in values),'median_warm_p95_ms':statistics.median(r['warm_p95_ms'] for r in values),'median_max_rss_bytes':statistics.median(r['max_rss_bytes'] for r in values)}
print(json.dumps(report,indent=2,sort_keys=True))
