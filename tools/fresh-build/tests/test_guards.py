#!/usr/bin/env python3
"""Small non-destructive checks; no build or input-source installation."""
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('fresh_build', ROOT / 'fresh-build.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class GuardTests(unittest.TestCase):
    def test_existing_destination_untouched(self):
        with tempfile.TemporaryDirectory(prefix='lekha-output-guard-') as tmp:
            target = Path(tmp) / 'existing'
            target.mkdir()
            marker = target / 'keep.txt'
            marker.write_text('preserve', encoding='utf-8')
            p = subprocess.run([sys.executable, str(ROOT / 'fresh-build.py'), '--project', tmp, '--output', str(target)], capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn('refusing to overwrite', p.stderr)
            self.assertEqual(marker.read_text(encoding='utf-8'), 'preserve')
            self.assertEqual([x.name for x in target.iterdir()], ['keep.txt'])

    def test_refuses_symlink_inputs(self):
        with tempfile.TemporaryDirectory(prefix='lekha-source-guard-') as tmp:
            root = Path(tmp)
            (root / 'Sources').mkdir(); (root / 'Tests').mkdir()
            (root / 'Sources' / 'linked.swift').symlink_to('/etc/hosts')
            with self.assertRaisesRegex(ValueError, 'symlink input refused'):
                module.collect(root)

    def test_refuses_output_inside_source(self):
        with tempfile.TemporaryDirectory(prefix='lekha-source-output-') as tmp:
            output = Path(tmp) / 'new-output'
            p = subprocess.run([sys.executable, str(ROOT / 'fresh-build.py'), '--project', tmp, '--output', str(output)], capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn('outside the source project', p.stderr)
            self.assertFalse(output.exists())

    def test_refuses_quarantined_input(self):
        with tempfile.TemporaryDirectory(prefix='lekha-quarantine-guard-') as tmp:
            root = Path(tmp)
            path = root / 'file.swift'
            path.write_text('test', encoding='utf-8')
            subprocess.run(['xattr', '-w', 'com.apple.quarantine', '0081;00000000;LekhaTest;', str(path)], check=True)
            with self.assertRaisesRegex(ValueError, 'quarantined input refused'):
                module.checked_input(root, Path('file.swift'))
            self.assertEqual(subprocess.run(['xattr', '-p', 'com.apple.quarantine', str(path)], capture_output=True).returncode, 0)

    def test_refuses_quarantined_parent(self):
        with tempfile.TemporaryDirectory(prefix='lekha-quarantine-parent-') as tmp:
            root = Path(tmp)
            parent = root / 'Sources'
            parent.mkdir()
            (parent / 'file.swift').write_text('test', encoding='utf-8')
            subprocess.run(['xattr', '-w', 'com.apple.quarantine', '0081;00000000;LekhaTest;', str(parent)], check=True)
            with self.assertRaisesRegex(ValueError, 'quarantined input refused'):
                module.checked_input(root, Path('Sources/file.swift'))
            self.assertEqual(subprocess.run(['xattr', '-p', 'com.apple.quarantine', str(parent)], capture_output=True).returncode, 0)

if __name__ == '__main__':
    unittest.main(verbosity=2)
