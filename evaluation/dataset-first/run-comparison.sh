#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
task_temp="$(mktemp -d "${TMPDIR:-/tmp}/neptype-compare.XXXXXX")"
trap 'rm -rf "$task_temp"' EXIT
export NEPTYPE_ALIAS_INDEX="$PWD/data/compiled/google-ne-aliases.tsv"
export NEPTYPE_AKSHARANTAR_INDEX="$PWD/data/compiled/aksharantar-indiccorp-v1.tsv"
for variant in before candidate; do
  swiftc -O -module-cache-path "$task_temp/cache" "evaluation/dataset-first/Transliterator.$variant.swift" Sources/NepaliCore/Composer.swift Sources/NepaliCore/GeneratedIndexes.swift Sources/NepaliCore/GeneratedAliasIndex.swift evaluation/phase0/main.swift -o "$task_temp/$variant"
  "$task_temp/$variant" evaluation/phase0/corpus-v1.json > "$task_temp/$variant.json"
done
python3 - "$task_temp/before.json" "$task_temp/candidate.json" <<'PY'
import json,sys
for name,path in zip(('before','candidate'),sys.argv[1:]):
 print(name, json.dumps(json.load(open(path))['summary'],ensure_ascii=False,sort_keys=True))
PY
