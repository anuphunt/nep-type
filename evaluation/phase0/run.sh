#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
task_temp="$(mktemp -d "${TMPDIR:-/tmp}/lekha-eval.XXXXXX")"
trap 'rm -rf "$task_temp"' EXIT
swiftc -O -module-cache-path "$task_temp/module-cache" Sources/NepaliCore/Transliterator.swift Sources/NepaliCore/Composer.swift Sources/NepaliCore/GeneratedIndexes.swift Sources/NepaliCore/GeneratedAliasIndex.swift evaluation/phase0/main.swift -o "$task_temp/lekha-evaluate"
LEKHA_ALIAS_INDEX="$PWD/data/compiled/google-ne-aliases.tsv" LEKHA_AKSHARANTAR_INDEX="$PWD/data/compiled/aksharantar-indiccorp-v1.tsv" "$task_temp/lekha-evaluate" "${1:-evaluation/phase0/corpus-v1.json}"
