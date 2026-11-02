#!/bin/sh
# Compatibility entry point. Apple targets now reference canonical files directly.
set -eu
mode=--check
if [ "$#" -ge 1 ]; then mode="$1"; fi
case "$mode" in --check|--sync) ;; *) echo "Usage: $0 [--check|--sync] [NEPTYPE_ROOT]" >&2; exit 2;; esac
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root="$project_dir/../.."
if [ "$#" -ge 2 ]; then root="$2"; fi
python3 "$root/scripts/check-shared-engine.py" --ios-only
python3 "$root/scripts/engine-data.py" check
