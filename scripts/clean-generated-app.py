#!/usr/bin/env python3
"""Remove Finder decoration only from a generated app before signature checks."""
import subprocess, sys
from pathlib import Path
root=Path(sys.argv[1])
assert root.suffix=='.app' and root.is_dir() and not root.is_symlink()
# Traverse first, then clean child paths before the enclosing bundle. Recursive
# xattr can leave decoration on nested bundles copied into File Provider folders.
paths=sorted(root.rglob('*'),key=lambda p:len(p.parts),reverse=True)+[root]
for p in paths:
    if p.is_symlink():continue
    for name in ('com.apple.ResourceFork','com.apple.FinderInfo'):
        result=subprocess.run(['xattr','-d',name,str(p)],capture_output=True,text=True)
        if result.returncode and 'No such xattr' not in result.stderr:
            raise RuntimeError(result.stderr)
