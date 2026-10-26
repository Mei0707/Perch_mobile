// Local fixture server for exercising Foundation's real JSON/SSE client.
// No provider keys or external network calls are used.
import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createServer } from './server.mjs';
const directory = await mkdtemp(join(tmpdir(), 'perch-native-'));
const quotes = ['NVDA', 'AAPL'].map(ticker => ({ ticker, name: ticker, sector: 'Technology', price: 10,
  previousClose: ticker === 'NVDA' ? 12 : 10, asOf: new Date().toISOString(), source: 'Finnhub', freshness: 'fresh' }));
const server = createServer({ analyticsPath: join(directory, 'events.jsonl'), market: {
  quotes: async () => ({ quotes, unavailable: [] }), quote: async ticker => quotes.find(q => q.ticker === ticker)
}, model: {
  plan: async input => input.some(item => item.type === 'function_call_output') ? [] : [{ type: 'function_call',
    call_id: 'native-scenario', name: 'simulateTrade', arguments: '{"ticker":"NVDA","reductionPercent":20}' }],
  explain: async (_, facts, onDraft) => {
    onDraft('Calculating the illustrative allocation.');
    return { title: 'Illustrative sale', explanationTemplate: 'NVDA allocation after sale is {{scenario.after}}.',
      factIDs: ['scenario.after'], limitations: ['Proceeds remain as cash. Holdings are unchanged.'] };
  }
} });
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
try {
  const child = spawn(process.argv[2], [], { stdio: 'inherit', env: { ...process.env,
    PERCH_VERIFY_API_URL: `http://127.0.0.1:${server.address().port}` } });
  const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('exit', resolve); });
  if (code !== 0) process.exitCode = code ?? 1;
} finally {
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
  await rm(directory, { recursive: true, force: true });
}
