import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DailyBudget, validateDeployment } from '../security.mjs';

test('exposed demo refuses short tokens, whitespace tokens and missing production providers', () => {
  assert.doesNotThrow(() => validateDeployment({}));
  assert.throws(() => validateDeployment({ host: '0.0.0.0', token: 'short' }));
  assert.throws(() => validateDeployment({ production: true, token: 'x'.repeat(32) }));
  assert.throws(() => validateDeployment({ host: '0.0.0.0', token: ' '.repeat(32) }));
  assert.doesNotThrow(() => validateDeployment({ production: true, token: 'x'.repeat(43), openAIKey: 'configured', finnhubKey: 'configured' }));
});
test('daily quota survives restarts, serializes concurrent reservations, and resets on UTC day change', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'perch-budget-'));
  const path = join(directory, 'quota.json');
  let now = new Date('2026-10-26T23:59:59Z');
  try {
    const first = new DailyBudget({ limit: 2, path, now: () => now });
    assert.deepEqual(await Promise.all([first.reserve(), first.reserve(), first.reserve()]), [true, true, false]);
    const restarted = new DailyBudget({ limit: 2, path, now: () => now });
    assert.equal(await restarted.reserve(), false);
    now = new Date('2026-10-27T00:00:00Z');
    assert.equal(await restarted.reserve(), true);
  } finally { await rm(directory, { recursive: true, force: true }); }
});
test('corrupted quota state fails closed on every attempt', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'perch-budget-'));
  const path = join(directory, 'quota.json');
  try {
    await writeFile(path, '{"day":"not-a-date","used":-1}');
    const budget = new DailyBudget({ path });
    await assert.rejects(budget.reserve());
    await assert.rejects(budget.reserve());
  } finally { await rm(directory, { recursive: true, force: true }); }
});
