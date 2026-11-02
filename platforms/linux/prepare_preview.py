#!/usr/bin/env python3
"""Create a reproducible local source preview archive; never install or register it."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import zipfile

ROOT = Path(__file__).resolve().parent
FIXED = (2020, 1, 1, 0, 0, 0)


def files(root):
    """Use an allowlist so generated data, caches and unrelated files cannot leak."""
    fixed = ["app.py", "run-pad.sh", "README.md", "run-engine.sh", "generate_descriptor.py", "diagnose.py", "prepare_preview.py",
             "lekha_ibus/__init__.py", "lekha_ibus/__main__.py", "lekha_ibus/engine.py", "lekha_ibus/policy.py",
             "lekha_ibus/bridge.py", "lekha_ibus/worker.py", "tests/test_bridge.py", "tests/test_foundation.py",
             "tests/test_mode_property.py", "tests/test_policy.py", "tests/test_packaging.py"]
    for directory in ("lekha_ibus", "tests"):
        base = root / directory
        if base.is_symlink() or not base.is_dir():
            raise ValueError(f"Missing or linked source directory: {directory}")
    paths = [root / name for name in fixed]
    for path in paths:
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Missing or linked source file: {path.name}")
    return sorted(paths, key=lambda p: p.relative_to(root).as_posix())


def prepare(output, root=ROOT):
    source = files(root)
    payload = [(path.relative_to(root).as_posix(), path.read_bytes()) for path in source]
    manifest = {
        "format": "lekha-linux-source-preview-v1",
        "notice": "Source-only local research preview. No IBus registration, compiled core or datasets included; not a release.",
        "sha256": {name: hashlib.sha256(data).hexdigest() for name, data in payload},
    }
    payload.append(("PREVIEW-MANIFEST.json", (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()))
    # Exclusive creation avoids overwriting any existing file or following an existing symlink.
    with open(output, "xb") as raw, zipfile.ZipFile(raw, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in payload:
            entry = zipfile.ZipInfo("lekha-linux-preview/" + name, FIXED)
            entry.create_system = 3
            mode = 0o755 if name.endswith(".sh") else 0o644
            entry.external_attr = (stat.S_IFREG | mode) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    return hashlib.sha256(Path(output).read_bytes()).hexdigest()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", help="New .zip path; existing files are never overwritten")
    args = parser.parse_args()
    print(json.dumps({"path": os.path.abspath(args.output), "sha256": prepare(args.output)}, sort_keys=True))
