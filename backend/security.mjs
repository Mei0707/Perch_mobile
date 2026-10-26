import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { randomUUID } from 'node:crypto';

export function validateDeployment({ host = '127.0.0.1', production = false, token = '', openAIKey = '', finnhubKey = '' }) {
  const exposed = !['127.0.0.1', '::1', 'localhost'].includes(host);
  if ((exposed || production) && (token.length < 32 || /\s/.test(token))) throw new Error('Exposed hosting requires a random PERCH_API_TOKEN of at least 32 characters');
  if (production && (!openAIKey.trim() || !finnhubKey.trim())) throw new Error('Production requires both provider keys');
}
// Single-instance demo quota. Persist before spending; restarts cannot reset today's budget.
// Multiple replicas must replace this with a transactional shared store.
export class DailyBudget {
  constructor({ limit = 50, path, now = () => new Date() } = {}) {
    if (!Number.isInteger(limit) || limit < 1 || limit > 10000) throw new Error('Invalid daily answer budget');
    this.limit = limit; this.path = path; this.now = now; this.queue = Promise.resolve(); this.state = null;
  }
  reserve() {
    const operation = this.queue.then(async () => {
      const day = this.now().toISOString().slice(0, 10);
      if (!this.state) {
        if (this.path) {
          try {
            const stored = JSON.parse(await readFile(this.path, 'utf8'));
            if (!/^\d{4}-\d{2}-\d{2}$/.test(stored.day) || !Number.isSafeInteger(stored.used) || stored.used < 0) throw new Error('Invalid quota state');
            this.state = stored;
          } catch (error) { if (error.code === 'ENOENT') this.state = { day, used: 0 }; else throw error; }
        } else this.state = { day, used: 0 };
      }
      if (this.state.day !== day) this.state = { day, used: 0 };
      if (this.state.used >= this.limit) return false;
      const next = { day, used: this.state.used + 1 };
      if (this.path) {
        await mkdir(dirname(this.path), { recursive: true });
        const temporary = `${this.path}.${randomUUID()}.tmp`;
        await writeFile(temporary, JSON.stringify(next), { mode: 0o600 });
        await rename(temporary, this.path);
      }
      this.state = next;
      return true;
    });
    this.queue = operation.catch(() => {});
    return operation;
  }
}
