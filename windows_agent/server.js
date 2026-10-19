'use strict';

const crypto = require('node:crypto');
const { spawn } = require('node:child_process');

const ENDPOINT = process.env.REMOTE_UNLOCK_ENDPOINT || '';
const PUBLISHABLE_KEY = process.env.REMOTE_UNLOCK_PUBLISHABLE_KEY || '';
const DEVICE_SECRET = process.env.REMOTE_UNLOCK_DEVICE_SECRET || '';
const POLL_INTERVAL_MS = Math.max(5000, Number(process.env.REMOTE_UNLOCK_POLL_MS || 10000));

if (!ENDPOINT.startsWith('https://') ||
    !ENDPOINT.endsWith('/functions/v1/remoteunlock') ||
    !PUBLISHABLE_KEY ||
    DEVICE_SECRET.length < 32) {
  console.error('Missing/invalid cloud relay configuration. Run .\\setup-cloud-secrets.ps1 and configure the agent endpoint.');
  process.exit(1);
}

function safeEqual(actual, expected) {
  const a = Buffer.from(String(actual || ''));
  const b = Buffer.from(String(expected || ''));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function pollOnce() {
  const response = await fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'apikey': PUBLISHABLE_KEY,
      'x-device-secret': DEVICE_SECRET,
    },
    body: JSON.stringify({ operation: 'poll' }),
    signal: AbortSignal.timeout(10000),
  });

  const raw = await response.text();
  let payload = {};
  try { payload = raw ? JSON.parse(raw) : {}; } catch { /* handled below */ }

  if (!response.ok) {
    if (response.status === 401) {
      throw new Error('Cloud relay rejected the device secret. Check REMOTE_UNLOCK_DEVICE_SECRET in Supabase and agent-config.json.');
    }
    throw new Error('Cloud relay returned HTTP ' + response.status + ': ' + raw.slice(0, 300));
  }

  const command = payload.command;
  if (!command) return;
  if (command.action !== 'lock') {
    console.warn('Ignored unsupported cloud command.');
    return;
  }

  const child = spawn('rundll32.exe', ['user32.dll,LockWorkStation'], {
    windowsHide: true,
    shell: false,
    stdio: 'ignore',
  });
  child.once('error', err => console.error('Could not execute Windows lock command:', err.message));
  child.once('spawn', () => console.log(new Date().toISOString(), 'Cloud lock command received and submitted to Windows.'));
}

async function main() {
  console.log('RemoteUnlock cloud agent started.');
  console.log('Endpoint:', ENDPOINT);
  console.log('Polling interval:', POLL_INTERVAL_MS + 'ms');
  console.log('This process only polls for lock commands; it does not open a listening port.');
  while (true) {
    try {
      await pollOnce();
    } catch (err) {
      console.error(new Date().toISOString(), err.message);
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
