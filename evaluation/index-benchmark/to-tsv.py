#!/usr/bin/env python3
import json, sys
work=json.load(open(sys.argv[1],encoding='utf8'))
with open(sys.argv[2],'w',encoding='utf8') as out:
 for item in work['cases']:
  assert '\t' not in item['key'] and '\n' not in item['key']
  out.write('\t'.join([item['category'],item['key']]+item['expected'])+'\n')
