import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../../', import.meta.url));
const read = (path) => readFileSync(join(root, path), 'utf8');

// Each suite runs production BrightScript in the brs interpreter. Only node
// construction and painting are replaced; navigation and request logic are real.
function runNative(t, name, sources, label) {
  const dir = mkdtempSync(join(tmpdir(), `luma-${name}-brs-`));
  try {
    const script = join(dir, `${name}.brs`);
    writeFileSync(script, sources.join('\n'));
    const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], { cwd: dir, encoding: 'utf8', timeout: 30_000 });
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
    const pass = new RegExp(`PASS:\\s*\\d+\\s+${label} assertions`);
    assert.match(output, pass, output);
    t.diagnostic(output.match(pass)[0]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('native search keyboard navigation, wide keys and page edges', (t) => {
  const keyboard = read('roku/components/SearchKeyboard.brs')
    .replace(/^sub init\(/m, 'sub NativeInit(')
    .replace(/^sub PaintKeys\(/m, 'sub NativePaintKeys(');
  runNative(t, 'search-keyboard', [read('roku/source/Utils.brs'), keyboard, read('tests/roku/search-keyboard.spec.brs')], 'search keyboard');
});

test('native search page debounce, single in-flight request, stale rejection and focus', (t) => {
  const screen = read('roku/components/SearchScreen.brs').replace(/^sub init\(/m, 'sub NativeInit(');
  runNative(t, 'search-screen', [read('roku/source/Utils.brs'), screen, read('tests/roku/search-screen.spec.brs')], 'search screen');
});

test('native search integration: non-blocking requests, details, Back and menu restoration', (t) => {
  const scene = read('roku/components/LumaScene.brs')
    .replace(/^sub PaintFocus\(/m, 'sub NativePaintFocus(')
    .replace(/^sub ShowMessage\(/m, 'sub NativeShowMessage(');
  runNative(t, 'search-scene', [read('roku/source/Utils.brs'), read('roku/components/PlaybackSession.brs'), scene, read('tests/roku/search-scene.spec.brs')], 'search scene');
});

test('search replaces the system keyboard dialog with the in-app page', () => {
  const scene = read('roku/components/LumaScene.brs');
  assert.doesNotMatch(scene, /OpenKeyboard\("search"/);
  assert.match(read('roku/components/LumaScene.xml'), /<SearchScreen id="searchScreen"/);
  for (const file of ['SearchScreen', 'SearchKeyboard', 'SearchResultCard']) {
    assert.doesNotMatch(read(`roku/components/${file}.brs`), /^\s*(sub|function)\s+RunService\s*\(/im);
  }
});
