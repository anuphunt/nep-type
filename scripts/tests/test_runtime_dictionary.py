"""Clean-checkout bootstrap and integrity failures, without external downloads."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RAW = ('roman-nepali-intentional.tsv.gz', 'roman-nepali-typos.tsv.gz', 'roman-nepali-reviewed.json')
sha = lambda value: hashlib.sha256(value).hexdigest()

class RuntimeBootstrap(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('scripts', 'engine/data', 'data/compiled', 'data/sources'):
            (self.root / directory).mkdir(parents=True)
        for script in ('engine-data.py', 'fetch-runtime-dictionary.py'):
            shutil.copyfile(ROOT / 'scripts' / script, self.root / 'scripts' / script)
        self.pack = b'NEPTYPE3' + b'fixture runtime bytes'
        wasm = b'wasm prefix' + self.pack + b'trailer'
        self.download = self.root / 'runtime.gz'
        zipped = gzip.compress(wasm)
        self.download.write_bytes(zipped)
        provenance = b'{"fixture":true}\n'
        (self.root/'engine/data/roman-nepali-provenance.json').write_bytes(provenance)
        (self.root/'data/compiled/roman-nepali.manifest.json').write_bytes(provenance)
        (self.root/'data/sources/english.txt').write_bytes(b'english')
        manifest = {'schema':3, 'dictionary':'roman-nepali-v2-pilot-v1', 'id':'fixture',
                    'bytes':len(self.pack), 'sha256':sha(self.pack), 'sources':{
                        **{'data/compiled/'+name:sha(b'private export') for name in RAW},
                        'data/compiled/roman-nepali.manifest.json':sha(provenance),
                        'data/sources/english.txt':sha(b'english')}}
        (self.root/'engine/data/manifest.json').write_text(json.dumps(manifest))
        source = {'url':self.download.as_uri(), 'compressed_sha256':sha(zipped),
                  'wasm_sha256':sha(wasm), 'wasm_bytes':len(wasm), 'pack_offset':len(b'wasm prefix')}
        (self.root/'engine/data/runtime-source.json').write_text(json.dumps(source))
    def check(self):
        import os
        env = dict(os.environ); env.pop('NEPTYPE_PACK_ONLY', None)
        return subprocess.run([sys.executable, str(self.root/'scripts/engine-data.py'), 'check'],
                              capture_output=True, text=True, env=env)
    def test_clean_checkout_fetches_and_reuses_verified_pack(self):
        result = self.check(); self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root/'engine/data/neptype.pack').read_bytes(), self.pack)
        self.download.unlink()
        self.assertEqual(self.check().returncode, 0)
        self.assertFalse(any((self.root/'data/compiled'/name).exists() for name in RAW))
    def test_corrupt_download_does_not_install_pack(self):
        self.download.write_bytes(b'bad download')
        self.assertNotEqual(self.check().returncode, 0)
        self.assertFalse((self.root/'engine/data/neptype.pack').exists())
    def test_cached_pack_corruption_is_rejected(self):
        (self.root/'engine/data/neptype.pack').write_bytes(b'corrupt cache')
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('pinned fingerprint', result.stderr)
    def test_partial_private_exports_are_not_silently_ignored(self):
        (self.root/'data/compiled'/RAW[0]).write_bytes(b'private export')
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Incomplete dictionary exports', result.stderr)
    def test_present_public_source_corruption_is_rejected(self):
        (self.root/'data/sources/english.txt').write_bytes(b'changed')
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Dictionary source changed', result.stderr)

if __name__ == '__main__': unittest.main()
