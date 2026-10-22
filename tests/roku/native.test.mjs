import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../../', import.meta.url));
const read = (path) => readFileSync(join(root, path), 'utf8');

test('native BrightScript identity, persistence, DHCP recovery and authentication behavior', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'luma-brs-'));
  try {
    const service = read('roku/components/JellyfinTask.brs')
      .replace(/^function Http\(/m, 'function NativeHttp(')
      .replace(/^function HttpAll\(/m, 'function NativeHttpAll(')
      .replace(/^function Discover\(/m, 'function NativeDiscover(')
      .replace(/^sub Persist\(/m, 'sub NativePersist(');
    const script = join(dir, 'native.brs');
    writeFileSync(script, `${read('roku/source/Utils.brs').replace(/^function Encode\(/m, 'function NativeEncode(')}\n${service}\n${read('tests/roku/identity.spec.brs')}`);
    const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], {
      cwd: dir, encoding: 'utf8', timeout: 30_000,
    });
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
    assert.match(output, /PASS:\s*\d+\s+native assertions/, output);
    t.diagnostic(output.match(/PASS:\s*\d+\s+native assertions/)[0]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('native playback lifecycle and report backpressure', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'luma-scene-brs-'));
  try {
    // Only focus/rendering is stubbed; execute the real state handlers, report
    // payload creation, Send, and result acknowledgement logic.
    const scene = read('roku/components/LumaScene.brs')
      .replace(/^sub Focus\(/m, 'sub NativeFocus(')
      .replace(/^sub ShowMessage\(/m, 'sub NativeShowMessage(');
    const script = join(dir, 'scene.brs');
    writeFileSync(script, `${read('roku/source/Utils.brs')}\n${read('roku/components/PlaybackSession.brs')}\n${scene}\n${read('tests/roku/playback.spec.brs')}`);
    const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], {
      cwd: dir, encoding: 'utf8', timeout: 30_000,
    });
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
    assert.match(output, /PASS:\s*\d+\s+playback assertions/, output);
    t.diagnostic(output.match(/PASS:\s*\d+\s+playback assertions/)[0]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('native sidebar, content focus, back navigation and signed-out state', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'luma-navigation-brs-'));
  try {
    // Keep the real Focus, onKeyEvent and page restoration. Replace only paint
    // and dialog boundaries, which require a physical SceneGraph renderer.
    const scene = read('roku/components/LumaScene.brs')
      .replace(/^sub PaintFocus\(/m, 'sub NativePaintFocus(')
      .replace(/^sub ShowMessage\(/m, 'sub NativeShowMessage(');
    const script = join(dir, 'navigation.brs');
    writeFileSync(script, `${read('roku/source/Utils.brs')}\n${read('roku/components/PlaybackSession.brs')}\n${scene}\n${read('tests/roku/navigation.spec.brs')}`);
    const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], {
      cwd: dir, encoding: 'utf8', timeout: 30_000,
    });
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
    assert.match(output, /PASS:\s*\d+\s+navigation assertions/, output);
    t.diagnostic(output.match(/PASS:\s*\d+\s+navigation assertions/)[0]);
    // Voltar is a real, labelled control above the detail title (y=522), clear of the Menu hint.
    const back = read('roku/components/LumaScene.xml').match(/<Group id="backButton" translation="\[80,(\d+)\]"[\s\S]*?text="‹  Voltar"/);
    assert.ok(back, 'detail page declares a visible Voltar control');
    assert.ok(Number(back[1]) > 73 && Number(back[1]) + 58 < 522, 'Voltar sits between the Menu hint and the detail identity');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('native real track/version selection, quality ceilings and subtitle delivery', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'luma-options-brs-'));
  try {
    const service = read('roku/components/JellyfinTask.brs')
      .replace(/^function Http\(/m, 'function NativeHttp(')
      .replace(/^function OriginalVideoCapabilities\(/m, 'function NativeOriginalVideoCapabilities(')
      .replace(/^function AudioCapabilities\(/m, 'function NativeAudioCapabilities(')
      // brs 0.45 incorrectly types SubtitleTracks as assocarray; Roku specifies
      // an array of AAs. Stub only the playback metadata node, not policy logic.
      .replace('node = CreateObject("roSGNode", "ContentNode")\n    node.url = url', 'node = {}\n    node.url = url');
    const script = join(dir, 'options.brs');
    writeFileSync(script, `${read('roku/source/Utils.brs').replace(/^function Encode\(/m, 'function NativeEncode(')}\n${service}\n${read('tests/roku/playback-options.spec.brs')}`);
    const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], { cwd: dir, encoding: 'utf8', timeout: 30_000 });
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
    assert.match(output, /PASS:\s*\d+\s+playback option assertions/, output);
    t.diagnostic(output.match(/PASS:\s*\d+\s+playback option assertions/)[0]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('native playback replacement retains position, pause, selection and session ordering', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'luma-switch-brs-'));
  try {
    const scene = read('roku/components/LumaScene.brs')
      .replace(/^sub Focus\(/m, 'sub NativeFocus(')
      .replace(/^sub ShowMessage\(/m, 'sub NativeShowMessage(');
    const session = read('roku/components/PlaybackSession.brs').replace(/^sub ReplaceVideoNode\(/m, 'sub NativeReplaceVideoNode(');
    const script = join(dir, 'switch.brs');
    writeFileSync(script, `${read('roku/source/Utils.brs')}\n${session}\n${scene}\n${read('tests/roku/playback-switch.spec.brs')}`);
    const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], { cwd: dir, encoding: 'utf8', timeout: 30_000 });
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
    assert.match(output, /PASS:\s*\d+\s+playback switch assertions/, output);
    t.diagnostic(output.match(/PASS:\s*\d+\s+playback switch assertions/)[0]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('native player remote menus, long lists, checkmarks and chapter selection', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'luma-controls-brs-'));
  try {
    const controls = read('roku/components/PlayerControls.brs')
      .replace(/^sub PaintMenu\(/m, 'sub NativePaintMenu(')
      .replace(/^sub PaintControls\(/m, 'sub NativePaintControls(')
      .replace(/^sub PaintSkip\(/m, 'sub NativePaintSkip(');
    const script = join(dir, 'controls.brs');
    writeFileSync(script, `${read('roku/source/Utils.brs')}\n${controls}\n${read('tests/roku/player-controls.spec.brs')}`);
    const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], { cwd: dir, encoding: 'utf8', timeout: 30_000 });
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /FAIL:|Error occurred|Attempting to/);
    assert.match(output, /PASS:\s*\d+\s+player control assertions/, output);
    t.diagnostic(output.match(/PASS:\s*\d+\s+player control assertions/)[0]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
