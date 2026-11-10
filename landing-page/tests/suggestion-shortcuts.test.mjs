import test from 'node:test';
import assert from 'node:assert/strict';
import {usesNumberSuggestions, candidateIndex} from '../suggestion-shortcuts.mjs';

test('number-only suggestions cover phones and tablets without changing desktop shortcuts', () => {
  for (const device of [
    {userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)'},
    {userAgent:'Mozilla/5.0 (iPad; CPU OS 18_0)'},
    {platform:'MacIntel',maxTouchPoints:5},
    {userAgent:'Mozilla/5.0 (Linux; Android 14)'}
  ]) assert.equal(usesNumberSuggestions(device),true);
  assert.equal(usesNumberSuggestions({platform:'Win32',maxTouchPoints:10},true),true);
  for (const device of [{platform:'MacIntel'}, {platform:'Win32'}, {platform:'Linux'}, {}]) {
    assert.equal(usesNumberSuggestions(device),false);
    assert.equal(usesNumberSuggestions(device,true),false);
  }
  assert.equal(usesNumberSuggestions({platform:'Win32',maxTouchPoints:10},false),false);
});

test('only individual visible candidate digits qualify as selection input', () => {
  for (let digit=1;digit<=5;digit++) assert.equal(candidateIndex(String(digit)),digit-1);
  for (const text of ['0','6','9','12',' 1','1 ','१','',null,undefined]) assert.equal(candidateIndex(text),-1);
});
