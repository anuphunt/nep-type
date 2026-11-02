#!/bin/sh
# Starts only the standalone GTK window; does not register an input source.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$root/app.py" "$@"
