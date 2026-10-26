import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { randomBytes, randomUUID } from 'node:crypto';
const exec = promisify(execFile);
const docker = (...args) => exec('docker', args, { timeout: 30_000, maxBuffer: 1_000_000 });
const image = process.argv[2] ?? 'perch-api:verification';
const volume = `perch-verification-${randomUUID()}`;
const token = randomBytes(32).toString('base64url');
let container;
await docker('volume', 'create', volume);
try {
  const result = await docker('run', '--detach', '--rm', '--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges:true',
    '--memory', '256m', '--cpus', '0.5', '--tmpfs', '/tmp', '--publish', '127.0.0.1::8787',
    '--mount', `type=volume,source=${volume},target=/app/data`, '--env', `PERCH_API_TOKEN=${token}`,
    '--env', 'OPENAI_API_KEY=fixture-not-a-real-key', '--env', 'FINNHUB_API_KEY=fixture-not-a-real-key', image);
  container = result.stdout.trim();
  const port = (await docker('port', container, '8787/tcp')).stdout.trim().split(':').at(-1);
  const base = `http://127.0.0.1:${port}`;
  let health = false;
  for (let i = 0; i < 100; i++) {
    try { health = (await fetch(`${base}/health`, { signal: AbortSignal.timeout(500) })).ok; } catch {}
    if (health) break;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  if (!health) throw new Error('Container did not become healthy');
  if ((await fetch(`${base}/v1/status`)).status !== 401) throw new Error('Unauthenticated request was accepted');
  const status = await (await fetch(`${base}/v1/status`, { headers: { Authorization: `Bearer ${token}` } })).json();
  if (!status.marketConfigured || !status.aiConfigured) throw new Error('Configured readiness failed');
  const info = JSON.parse((await docker('inspect', container)).stdout)[0];
  if (info.Config.User !== 'node' || !info.HostConfig.ReadonlyRootfs || !info.HostConfig.CapDrop.includes('ALL')) throw new Error('Container isolation settings failed');
  await docker('exec', container, 'node', '-e', `const fs=require('node:fs');fs.writeFileSync('/app/data/permission-check','ok');let blocked=false;try{fs.writeFileSync('/app/should-fail','x')}catch(e){blocked=e.code==='EROFS'}if(!blocked)process.exit(1)`);
  console.log(JSON.stringify({ image, passed: true, checks: ['liveness', 'authentication required', 'authenticated readiness', 'non-root read-only isolation', 'writable persistent data and protected application files'],
    providerRequestsMade: 0 }, null, 2));
} finally {
  if (container) await docker('rm', '--force', container).catch(() => {});
  await docker('volume', 'rm', volume).catch(() => {});
}
