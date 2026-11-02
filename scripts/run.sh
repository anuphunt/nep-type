#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -x build/Lekha.app/Contents/MacOS/Lekha ]; then bash scripts/build.sh; fi
open build/Lekha.app
