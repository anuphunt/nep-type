#!/bin/bash
# Research-only; writes to the named scratch directory and never edits app files.
set -euo pipefail
if [ "$#" -ne 2 ]; then echo 'Usage: run-parity.sh NEPTYPE_ROOT EMPTY_SCRATCH_DIR' >&2; exit 2; fi
root=$(CDPATH= cd -- "$1" && pwd)
work=$2
if [ -e "$work" ]; then echo 'Scratch path already exists; refusing overwrite' >&2; exit 1; fi
mkdir -p "$work"
study=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
google="$root/data/compiled/google-ne-aliases.tsv"
mined="$root/data/compiled/aksharantar-indiccorp-v1.tsv"
python3 "$study/pack-index.py" "$google" "$work/google.lki" > "$work/google-manifest.json"
python3 "$study/pack-index.py" "$mined" "$work/mined.lki" > "$work/mined-manifest.json"
python3 "$study/verify-exhaustive.py" "$google" "$work/google.lki"
python3 "$study/verify-exhaustive.py" "$mined" "$work/mined.lki"
cp "$study/AllRows/main.swift" "$work/main.swift"
xcrun swiftc -O -module-cache-path "$work/cache" "$root/Sources/NepaliCore/GeneratedAliasIndex.swift" "$study/PackedIndex.swift" "$work/main.swift" -o "$work/all"
export NEPTYPE_ALIAS_INDEX="$google" NEPTYPE_AKSHARANTAR_INDEX="$mined"
cut -f1 "$google" | "$work/all" "$work/google.lki" google
cut -f1 "$mined" | "$work/all" "$work/mined.lki" mined
cp "$study/Corruption/main.swift" "$work/main.swift"
xcrun swiftc -O -module-cache-path "$work/cache" "$study/PackedIndex.swift" "$work/main.swift" -o "$work/corrupt"
python3 "$study/test-corruption.py" "$study" "$work/corrupt"
