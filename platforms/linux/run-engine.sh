#!/bin/sh
# Internal launcher for an explicitly registered component. Does not register it.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$project_dir"
exec "${1:-python3}" -m neptype_ibus
