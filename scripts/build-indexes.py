#!/usr/bin/env python3
"""Compatibility entry point: rebuild the single Rust dictionary pack."""
import subprocess,sys
from pathlib import Path
subprocess.run([sys.executable,str(Path(__file__).with_name('build-dictionary-pack.py'))],check=True)
