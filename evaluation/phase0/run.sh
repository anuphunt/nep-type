#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
task_temp="$(mktemp -d "${TMPDIR:-/tmp}/neptype-eval.XXXXXX")"
trap 'rm -rf "$task_temp"' EXIT
swiftc -O -module-cache-path "$task_temp/module-cache" Sources/NepaliCore/Transliterator.swift Sources/NepaliCore/Composer.swift Sources/NepaliCore/GeneratedIndexes.swift Sources/NepaliCore/GeneratedAliasIndex.swift evaluation/phase0/main.swift -o "$task_temp/neptype-evaluate"
NEPTYPE_ALIAS_INDEX="$PWD/data/compiled/google-ne-aliases.tsv" NEPTYPE_AKSHARANTAR_INDEX="$PWD/data/compiled/aksharantar-indiccorp-v1.tsv" "$task_temp/neptype-evaluate" "${1:-evaluation/phase0/corpus-v1.json}"
