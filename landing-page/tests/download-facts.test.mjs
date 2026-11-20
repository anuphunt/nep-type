import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {releaseFacts} from '../download-page.mjs';
import {pages} from '../page-content.mjs';

test('release facts show the recorded version and decimal megabytes', () => {
  assert.equal(releaseFacts('en', {version:'0.1.3', bytes:546494752}), 'Version 0.1.3 · 546 MB');
  assert.equal(releaseFacts('ne', {version:'0.1.3-preview.1', bytes:93288298}), 'संस्करण 0.1.3-preview.1 · 93 MB');
  for (const release of [null, {version:'0.1.3'}, {version:'0.1.3', bytes:0}, {bytes:10}]) assert.equal(releaseFacts('en', release), '');
});

test('the current release files have a version and size to disclose', async () => {
  for (const file of ['../mac-release.json', '../windows-release.json']) {
    const release = JSON.parse(await readFile(new URL(file, import.meta.url), 'utf8'));
    assert.match(releaseFacts('en', release), /^Version \d+\.\d+\.\d+(-preview\.\d+)? · \d+ MB$/);
  }
});

test('the FAQ offline answer links the offline guide in both languages', () => {
  for (const locale of ['en', 'ne']) {
    const answer = pages.faq[locale].sections[2];
    assert.ok(answer[2]?.links?.some(([, href]) => href === '/articles/nepali-typing-browser-offline-check/'), locale);
  }
});
