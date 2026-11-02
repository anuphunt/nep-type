#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/lekha-phase2.XXXXXX")"
trap 'rm -rf "$task_tmp"' EXIT
swiftc -O -module-cache-path "$task_tmp/cache" Sources/NepaliCore/Transliterator.swift Sources/NepaliCore/Composer.swift Sources/NepaliCore/GeneratedIndexes.swift Sources/NepaliCore/GeneratedAliasIndex.swift evaluation/phase2/main.swift -o "$task_tmp/evaluate"
LEKHA_ALIAS_INDEX="$PWD/data/compiled/google-ne-aliases.tsv" LEKHA_AKSHARANTAR_INDEX="$PWD/data/compiled/aksharantar-indiccorp-v1.tsv" "$task_tmp/evaluate" "${1:-evaluation/phase0/corpus-v1.json}"
