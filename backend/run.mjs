// npm may prepend an older ancestor node_modules/.bin/node to PATH. Use the
// runtime that actually launched npm so CLI flags and the engine requirement agree.
import { spawn, spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const runtime = process.env.npm_node_execpath || process.execPath;
const version = spawnSync(runtime, ['-p', 'process.versions.node'], { encoding: 'utf8' });
if (process.argv[2] === 'runtime') { console.log(JSON.stringify({ bootstrap: process.versions.node, runtime, version: (version.stdout || '').trim(), status: version.status, error: version.error?.code })); process.exit(0); }
const [major, minor] = (version.stdout || '').trim().split('.').map(Number);
if (version.status !== 0 || !Number.isInteger(major) || major < 22 || (major === 22 && minor < 9)) {
  console.error('Perch requires Node 22.9 or newer. Select a supported Node version before running npm.');
  process.exit(2);
}
const tasks = {
  start: ['--env-file-if-exists=.env', 'server.mjs'],
  test: ['--test', ...readdirSync(new URL('./test/', import.meta.url)).filter(name => name.endsWith('.test.mjs')).map(name => `test/${name}`)],
  eval: ['evaluate.mjs'],
  providers: ['--env-file-if-exists=.env', 'provider-smoke.mjs'],
  http: ['--env-file-if-exists=.env', 'verify-live-http.mjs'],
  benchmark: ['--env-file-if-exists=.env', 'evaluate.mjs', '--live']
};
const args = tasks[process.argv[2]];
if (!args) { console.error('Unknown Perch task'); process.exit(2); }
const child = spawn(runtime, [...args, ...process.argv.slice(3)], { stdio: 'inherit', cwd: fileURLToPath(new URL('.', import.meta.url)) });
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => child.kill(signal));
child.on('error', () => { console.error('Could not start the Perch task'); process.exitCode = 1; });
child.on('exit', code => { process.exitCode = code ?? 1; });
