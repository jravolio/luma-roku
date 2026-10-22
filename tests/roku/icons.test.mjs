import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

test('packaged icons retain the current web SVG geometry and PNG bytes', () => {
  const result = spawnSync('python3', ['scripts/generate-roku-icons.py', '--check'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const manifest = JSON.parse(readFileSync('roku/images/icons/manifest.json', 'utf8'));
  for (const name of Object.keys(manifest)) {
    const png = readFileSync(`roku/images/icons/${name}.png`);
    assert.equal(png.subarray(1, 4).toString(), 'PNG');
    assert.equal(png.readUInt32BE(16), 48);
    assert.equal(png.readUInt32BE(20), 48);
    assert.equal(png[25], 6, 'icons must retain RGBA transparency');
  }
});
