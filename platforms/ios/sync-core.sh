#!/bin/sh
# Keep this extension's checked-in snapshot aligned with NepType's primary core.
set -eu
mode="${1:---check}"
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root="${2:-$project_dir/../..}"
case "$mode" in --check|--sync) ;; *) echo "Usage: $0 [--check|--sync] [NEPTYPE_ROOT]" >&2; exit 2 ;; esac
check_file() {
    source=$1
    destination=$2
    if [ "$mode" = --sync ]; then
        test -f "$source" || { echo "Missing source: $source" >&2; exit 1; }
        cp "$source" "$destination"
    elif ! cmp -s "$source" "$destination"; then
        echo "iOS engine snapshot differs or is missing: $source" >&2
        echo "Run $0 --sync $root, then rebuild and retest." >&2
        exit 1
    fi
}
for name in InputSession Transliterator GeneratedIndexes GeneratedAliasIndex; do
    check_file "$root/Sources/NepaliCore/$name.swift" "$project_dir/NepTypeKeyboard/SharedCore/$name.swift"
done
for name in google-ne-aliases.tsv aksharantar-indiccorp-v1.tsv aksharantar-indiccorp-v1.manifest.json; do
    check_file "$root/data/compiled/$name" "$project_dir/NepTypeKeyboard/Resources/$name"
done
for name in CMUDICT-LICENSE.txt GOOGLE-NE-ATTRIBUTION.txt AKSHARANTAR-ATTRIBUTION.txt; do
    check_file "$root/data/sources/$name" "$project_dir/NepTypeKeyboard/Resources/$name"
done
