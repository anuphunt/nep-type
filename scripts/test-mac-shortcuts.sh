#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary="${1:-$root/build/shortcuts-swift/release/NepType}"
report="${2:-${TMPDIR:-/tmp}/neptype-mac-shortcut-checks.json}"
"$binary" --shortcut-test "$report"
python3 - "$report" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
failed=[name for name,passed in result['checks'].items() if not passed]
assert result['passed'] and not failed, failed
print(f"Passed {len(result['checks'])} AppKit key-event checks")
PY
