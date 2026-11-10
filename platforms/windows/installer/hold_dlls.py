"""CI-only process holding old keyboard modules while upgrade/removal runs."""
import ctypes
import json
import os
from pathlib import Path
import sys
import time

if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
    raise SystemExit('This fixture requires a disposable GitHub-hosted Windows runner.')
tsf, engine, ready, stop = map(Path, sys.argv[1:])
libraries = [ctypes.WinDLL(str(path), winmode=0x100 | 0x1000) for path in (tsf, engine)]
ready.write_text(json.dumps({'pid': os.getpid(), 'tsf': str(tsf), 'engine': str(engine)}), encoding='utf-8')
deadline = time.monotonic() + 900
while not stop.exists() and time.monotonic() < deadline:
    time.sleep(0.1)
if not stop.exists():
    raise SystemExit('DLL hold fixture timed out.')
