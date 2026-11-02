#!/usr/bin/env python3
"""Check offline engine fallback against small malformed index files.

This is a subprocess test, not a guarantee for all corruption or host behavior.
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

exe = sys.argv[1]
fixtures = {
    "empty": b"",
    "invalid_utf8": b"bhaisakeko\t\xff\xfe\n",
    "no_tab": b"bhaisakeko\n",
    "truncated": b"bhaisakeko\t\xe0\xa4",
    "binary": bytes(range(256)) * 8,
    "long_unterminated": b"bhaisakeko\t" + b"x" * 65536,
    "ascii_candidate": b"bhaisakeko\tattack\n",
    "mixed_candidate": "bhaisakeko\tभइसकेको\tattack\n".encode(),
    "oversized_candidate": ("bhaisakeko\t" + "क" * 61 + "\n").encode(),
    "empty_candidate": "bhaisakeko\tभइसकेको\t\n".encode(),
}
with tempfile.TemporaryDirectory(prefix="lekha-corrupt-index-") as directory:
    root = Path(directory)
    for name, raw in fixtures.items():
        index = root / (name + ".tsv")
        index.write_bytes(raw)
        env = dict(os.environ, LEKHA_ALIAS_INDEX=str(index), LEKHA_AKSHARANTAR_INDEX=str(index))
        commands = [{"id":"s","op":"create"}, {"id":"s","op":"append","text":"bhaisakeko"}, {"id":"s","op":"cancel"}]
        p = subprocess.run([exe], input="".join(json.dumps(x)+"\n" for x in commands), text=True, capture_output=True, env=env, timeout=10, check=True)
        rows = [json.loads(line) for line in p.stdout.splitlines()]
        assert len(rows) == 3 and rows[1]["ok"] and rows[2].get("result") == "bhaisakeko", (name, rows)
        assert "bhaisakeko" in rows[1]["state"]["candidates"], name
        assert rows[1]["state"]["markedText"] == "भैसकेको", (name, rows[1]["state"]["markedText"][:100])
        assert all(len(value) <= 60 for value in rows[1]["state"]["candidates"]), name
        print("PASS:", name, "keeps original available and cancellable")
