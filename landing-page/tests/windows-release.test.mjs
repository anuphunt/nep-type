import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {windowsDownload, windowsPage} from '../windows-release.mjs';

const verifiedFixture = {
  version:'0.1.0-preview.1', verified:true, sha256:'a'.repeat(64), bytes:123,
  sourceCommit:'b'.repeat(40), signing:'unsigned', systemKeyboard:false,
  verificationUrl:'https://github.com/anuphunt/nep-type/actions/runs/123',
  url:'https://github.com/anuphunt/nep-type/releases/download/windows-v0.1.0-preview.1/NepType-0.1.0-preview.1-windows-x64-setup.exe'
};
test('pending Windows builds never expose an installer download', async () => {
  assert.equal(windowsDownload({verified:false, url:verifiedFixture.url}), null);
  const current = windowsDownload(JSON.parse(await readFile(new URL('../windows-release.json',import.meta.url))));
  if (!current) assert.match(windowsPage(current,'en').sections[0][0], /in preparation/);
});
test('a Windows preview requires an immutable installer, checksum, source and CI evidence', () => {
  assert.equal(windowsDownload(verifiedFixture), verifiedFixture);
  for (const [key,value] of Object.entries({sha256:null,sourceCommit:null,bytes:0,signing:'signed',systemKeyboard:true,verificationUrl:null,url:'https://example.com/setup.exe'})) {
    assert.throws(()=>windowsDownload({...verifiedFixture,[key]:value}), undefined, key);
  }
  for (const locale of ['en','ne']) assert.equal(windowsPage(verifiedFixture,locale).sections.length,5);
  assert.match(JSON.stringify(windowsPage(verifiedFixture,'en')), /not digitally signed/);
  assert.match(JSON.stringify(windowsPage(verifiedFixture,'en')), /does not install a system keyboard/);
});
