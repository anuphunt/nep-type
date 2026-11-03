"""Real shared-library preferences and local-state failure cases; no GUI or network."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"python"))
from neptype_engine import Engine
from local_experience import LocalExperience

class ProductExperienceTests(unittest.TestCase):
    def test_real_preferences_are_handle_local_and_explicit_choice_wins(self):
        first,second=Engine(),Engine()
        try:
            baseline=second.document("pani",0,4)["output"]
            first.set_preferences({"pani":"पानी"})
            self.assertEqual(first.candidates("pani",0)[0],"पानी")
            preferred=first.document("pani",0,4)
            self.assertEqual(preferred["candidates"][0],"पानी")
            self.assertEqual(preferred["output"],baseline)
            self.assertEqual(second.document("pani",0,4)["output"],baseline)
            self.assertEqual(first.document("pani",0,4,"pani")["output"],"pani")
            literal="https://pani.com `pani` me@example.com"
            self.assertEqual(first.document(literal,0,0)["output"],literal)
            first.set_preferences({"pani":"private unoffered text"})
            self.assertNotEqual(first.document("pani pani",0,9)["output"],"private unoffered text")
        finally:first.close();second.close()

    def test_local_restore_and_corrupt_file(self):
        with tempfile.TemporaryDirectory() as directory:
            local=LocalExperience(directory)
            local.data.update(source="my private draft")
            local.remember("pani","पानी",["पनि","पानी"])
            self.assertTrue(local.save())
            restored=LocalExperience(directory)
            self.assertEqual(restored.data["source"],"my private draft")
            self.assertEqual(restored.data["spellings"],{"pani":"पानी"})
            restored.data.update(source="",spellings={});restored.save()
            self.assertNotIn("private",restored.path.read_text())
            if os.name != "nt": self.assertEqual(restored.path.stat().st_mode&0o777,0o600)
            restored.path.write_text('{"spellings": [], "remember": true}')
            self.assertEqual(LocalExperience(directory).data["spellings"],{})

if __name__=="__main__":unittest.main()
