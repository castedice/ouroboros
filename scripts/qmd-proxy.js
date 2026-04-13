#!/usr/bin/env bun
// qmd-proxy.js — Privacy-preserving QMD MCP proxy
//
// Wraps `qmd mcp` and masks text/content/snippet fields in responses
// via pa-mask.sh before they reach the MCP client.
//
// Usage in .mcp.json:
//   { "command": "bun", "args": ["scripts/qmd-proxy.js"] }

const { spawn } = require('node:child_process');
const { once } = require('node:events');
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');

const PA_MASK = path.join(__dirname, 'pa-mask.sh');
const QMD_BIN = process.env.QMD_BIN || 'qmd';
const ENV = { ...process.env };
const MASK_KEYS = new Set(['text', 'content', 'snippet']);
const CAN_MASK = fs.existsSync(PA_MASK);
const warn = (m) => process.stderr.write(`[qmd-proxy] ${m}\n`);

if (!process.env.PA_VAULT_PATH) warn('PA_VAULT_PATH is not set; masking will fail open');
if (!CAN_MASK) warn(`pa-mask.sh not found: ${PA_MASK}`);

function maskText(text) {
  if (!CAN_MASK || !text) return Promise.resolve(text);
  return new Promise((resolve) => {
    const p = spawn('/bin/bash', [PA_MASK, '--full'], { env: ENV, stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '';
    let done = false;
    const finish = (value, msg) => {
      if (done) return;
      done = true;
      if (msg) warn(msg);
      resolve(value);
    };
    p.on('error', (e) => finish(text, `pa-mask.sh error: ${e.message}`));
    p.stdout.setEncoding('utf8');
    p.stderr.setEncoding('utf8');
    p.stdout.on('data', (c) => { out += c; });
    p.on('close', (code) => {
      if (code === 0) finish(text.endsWith('\n') ? out : out.replace(/\n$/, ''));
      else finish(text, 'pa-mask.sh failed; passing through');
    });
    p.stdin.on('error', () => {});
    p.stdin.end(text);
  });
}

async function maskNode(node) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) { for (const item of node) await maskNode(item); return; }
  for (const [key, value] of Object.entries(node)) {
    if (MASK_KEYS.has(key) && typeof value === 'string') node[key] = await maskText(value);
    else if (value && typeof value === 'object') await maskNode(value);
  }
}

async function main() {
  const qmd = spawn(QMD_BIN, ['mcp'], { env: ENV, stdio: ['pipe', 'pipe', 'inherit'] });
  qmd.on('error', (e) => { warn(`qmd start failed: ${e.message}`); process.exit(127); });
  process.stdout.on('error', () => process.exit(0));
  qmd.stdin.on('error', () => {});
  process.stdin.pipe(qmd.stdin);
  for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => qmd.kill(sig));

  const rl = readline.createInterface({ input: qmd.stdout, crlfDelay: Infinity });
  for await (const line of rl) {
    let out = line;
    try { const json = JSON.parse(line); await maskNode(json); out = JSON.stringify(json); } catch {}
    process.stdout.write(out + '\n');
  }

  const [code, signal] = await once(qmd, 'close');
  process.exit(signal ? 1 : (code ?? 0));
}

main().catch((e) => { warn(`fatal: ${e.message}`); process.exit(1); });
