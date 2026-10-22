import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = process.cwd();
test('held Roku arrows accelerate a preview and commit one seek on release', t => {
  const dir=mkdtempSync(join(tmpdir(),'luma-held-seek-'));
  try {
    const read=p=>readFileSync(join(root,p),'utf8');
    const controls=read('roku/components/PlayerControls.brs').replace(/^sub PaintControls\(/m,'sub NativePaintControls(').replace(/^function ScrubElapsedMs\(/m,'function NativeScrubElapsedMs(');
    const file=join(dir,'seek.brs');
    writeFileSync(file,read('roku/source/Utils.brs')+'\n'+controls+'\n'+read('tests/roku/player-seek.spec.brs'));
    const result=spawnSync(process.execPath,[join(root,'node_modules/brs/bin/cli.js'),file],{cwd:dir,encoding:'utf8',timeout:30000});
    const output=result.stdout+'\n'+result.stderr;
    assert.equal(result.status,0,output);assert.doesNotMatch(output,/FAIL:|Error occurred|Attempting to/);
    assert.match(output,/PASS:\s*\d+\s+held seek assertions/);t.diagnostic(output.match(/PASS:\s*\d+\s+held seek assertions/)[0]);
  } finally { rmSync(dir,{recursive:true,force:true}); }
});
