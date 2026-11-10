import {detectPlatform} from './platform.mjs';

// iPad desktop mode and touch-first tablets need the same labels as phones.
// A narrow desktop window alone must not change its keyboard shortcuts.
export function usesNumberSuggestions(device = {}, coarsePointer = false) {
  return ['iOS', 'Android'].includes(detectPlatform(device)) ||
    (device.maxTouchPoints > 0 && coarsePointer);
}

export function candidateIndex(value) {
  return /^[1-5]$/.test(value || '') ? Number(value) - 1 : -1;
}
