import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const contract = new URL('./training-contract.ts', import.meta.url);
const source = await readFile(contract, 'utf8');

test('contract reserves distinct types and labels for physical prediction and ideal geometry', () => {
  assert.match(source, /kind: 'physics-prediction'/);
  assert.match(source, /kind: 'ideal-geometry'/);
  assert.match(source, /label: '理想几何提示'/);
  assert.match(source, /ideal geometry is not an implementation/);
});

test('contract provides placement reasons, repeatable drill presets, and immutable review frames', () => {
  for (const value of ['moving', 'outside-table', 'pocket-area', 'overlap', 'straight', 'one-cushion', 'two-cushion', 'RecordedFrame', 'ShotReview']) assert.match(source, new RegExp(value));
});
