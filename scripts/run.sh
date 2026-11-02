#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -x build/NepType.app/Contents/MacOS/NepType ]; then bash scripts/build.sh; fi
open build/NepType.app
