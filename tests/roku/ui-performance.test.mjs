import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../../', import.meta.url));
const read = path => readFileSync(join(root, path), 'utf8');
for (const [scenario, component] of [['carousel', 'LumaScene'], ['menu', 'PlayerControls'], ['card', 'PosterCard'], ['layout', 'UIMotion'], ['icons', 'PlayerControls']]) {
  test(`native UI allocation budget and visual state: ${scenario}`, t => {
    const dir = mkdtempSync(join(tmpdir(), 'luma-ui-perf-'));
    try {
      // Execute production handlers. Only SG object creation/tree boundaries are
      // replaced by counting nodes; no production algorithm or loop is stubbed.
      const source = [read('roku/source/Utils.brs'), read('roku/source/Icons.brs'), read(`roku/components/${component}.brs`)]
        .join('\n').replace(/CreateObject\(/g, 'PerfCreateObject(');
      const script = join(dir, 'perf.brs');
      writeFileSync(script, `${source}\n${read('tests/roku/ui-performance-common.brs')}\n${read(`tests/roku/ui-performance-${scenario}.brs`)}`);
      const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], { cwd: dir, encoding: 'utf8', timeout: 30_000 });
      const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
      assert.equal(result.status, 0, output);
      assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
      const measurement = JSON.parse(output.match(/MEASURE (.+)/)?.[1] ?? '{}');
      assert.equal(measurement.updates, 100, output);
      t.diagnostic(`${scenario}: ${JSON.stringify(measurement)}`);
      if (!process.env.LUMA_PERF_BASELINE) {
        assert.equal(measurement.nodes, 0, 'warm navigation must reuse existing SceneGraph nodes');
        assert.equal(measurement.finds, 0, 'warm updates must use cached node references');
      }
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });
}
