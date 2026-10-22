import { mkdir, open, readFile, rename, chmod, unlink } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { normalizeServerUrl } from './urls.mjs';
import { identifier } from './errors.mjs';

export const defaultSessionPath = fileURLToPath(new URL('./.local/session.json', import.meta.url));

export class SessionStore {
  constructor(path = defaultSessionPath) { this.path = resolve(path); }

  async load() {
    try {
      const value = JSON.parse(await readFile(this.path, 'utf8'));
      identifier(value.deviceId, 'deviceId');
      if (value.version !== 1) throw new Error('Unsupported saved session version.');
      if (value.account) {
        const a = value.account;
        identifier(a.serverId); identifier(a.userId);
        a.url = normalizeServerUrl(a.url);
        if (a.token !== undefined && (typeof a.token !== 'string' || !/^[a-zA-Z0-9_-]{1,4096}$/.test(a.token))) throw new Error('Invalid saved token.');
      }
      await chmod(this.path, 0o600);
      return value;
    } catch (error) {
      if (error.code !== 'ENOENT') throw new Error('Saved session cannot be read safely; it has been preserved.', { cause: error });
      const value = { version: 1, deviceId: randomUUID() };
      await this.save(value);
      return value;
    }
  }

  async save(value) {
    // Whitelist fields: passwords or upstream response objects never reach disk.
    const a = value.account;
    const data = { version: 1, deviceId: value.deviceId, ...(a ? { account: {
      serverId: a.serverId, serverName: a.serverName, url: a.url,
      userId: a.userId, userName: a.userName, ...(a.token ? { token: a.token } : {}),
      ...(a.username ? { username: a.username } : {}), ...(a.password ? { password: a.password } : {}),
    } } : {}) };
    const dir = dirname(this.path);
    await mkdir(dir, { recursive: true, mode: 0o700 });
    await chmod(dir, 0o700);
    const temp = `${this.path}.${randomUUID()}.tmp`;
    let file;
    try {
      file = await open(temp, 'wx', 0o600);
      await file.writeFile(JSON.stringify(data, null, 2) + '\n');
      await file.sync();
      await file.close(); file = undefined;
      await rename(temp, this.path);
      const directory = await open(dir, 'r');
      try { await directory.sync(); } finally { await directory.close(); }
    } finally {
      await file?.close();
      await unlink(temp).catch(error => { if (error.code !== 'ENOENT') throw error; });
    }
  }
}
