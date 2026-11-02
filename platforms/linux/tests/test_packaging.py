import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from diagnose import diagnostics, file_status
from prepare_preview import prepare


class PackagingTests(unittest.TestCase):
    def test_preview_is_deterministic_and_excludes_extra_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "source"
            shutil.copytree(ROOT, root)
            (root / "private-unrelated.txt").write_text("must not be included")
            (root / "tests" / "unrelated.py").write_text("must not be included")
            one, two = Path(temp) / "one.zip", Path(temp) / "two.zip"
            self.assertEqual(prepare(one, root), prepare(two, root))
            self.assertEqual(one.read_bytes(), two.read_bytes())
            with zipfile.ZipFile(one) as archive:
                names = archive.namelist()
                self.assertFalse(any("unrelated" in n for n in names))
                self.assertFalse(any(n.endswith((".tsv", ".app", ".pyc")) for n in names))
                manifest = json.loads(archive.read("neptype-linux-preview/PREVIEW-MANIFEST.json"))
                self.assertEqual(manifest["format"], "neptype-linux-source-preview-v1")
                for name, expected in manifest["sha256"].items():
                    self.assertEqual(hashlib.sha256(archive.read("neptype-linux-preview/" + name)).hexdigest(), expected)
            with self.assertRaises(FileExistsError):
                prepare(one, root)

    def test_preview_rejects_linked_input(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "source"
            shutil.copytree(ROOT, root)
            candidate = root / "neptype_ibus" / "policy.py"
            candidate.unlink()
            candidate.symlink_to(root / "README.md")
            with self.assertRaises(ValueError):
                prepare(Path(temp) / "preview.zip", root)

    def test_readonly_diagnostics_show_incomplete_configuration(self):
        result = diagnostics({})
        self.assertEqual(result["core"], "not configured")
        self.assertEqual(result["google_alias_index"], "not configured")
        self.assertFalse(result["focus_id_experiment"])
        self.assertIn("No daemon connection", result["notice"])
        self.assertEqual(file_status("relative/file"), "must be an absolute path")
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "file"
            path.write_text("example")
            os.chmod(path, 0o600)
            self.assertEqual(file_status(str(path), executable=True), "not executable")


if __name__ == "__main__":
    unittest.main()
