'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');

const HOST = '127.0.0.1';
const PORT = Number(process.env.REMOTE_UNLOCK_PORT || 8765);
const TOKEN = process.env.REMOTE_UNLOCK_TOKEN || '';

if (TOKEN.length < 32) {
  console.error('REMOTE_UNLOCK_TOKEN must be at least 32 characters. Use start-agent.ps1 to create a token.');
  process.exit(1);
}

function authorized(req) {
  const header = req.headers.authorization || '';
  const expected = Buffer.from('Bearer ' + TOKEN);
  const actual = Buffer.from(header);
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200);
    return res.end(JSON.stringify({ ok: true, service: 'RemoteUnlock Windows Agent', actions: ['lock'] }));
  }
  if (req.method !== 'POST' || req.url !== '/command') {
    res.writeHead(404);
    return res.end(JSON.stringify({ error: 'not_found' }));
  }
  if (!authorized(req)) {
    res.writeHead(401);
    return res.end(JSON.stringify({ error: 'unauthorized' }));
  }

  let body = '';
  req.on('data', chunk => {
    body += chunk;
    if (body.length > 1024) {
      res.writeHead(413);
      res.end(JSON.stringify({ error: 'payload_too_large' }));
      req.destroy();
    }
  });
  req.on('end', () => {
    let payload;
    try { payload = JSON.parse(body || '{}'); } catch {
      res.writeHead(400);
      return res.end(JSON.stringify({ error: 'invalid_json' }));
    }
    if (payload.action !== 'lock') {
      res.writeHead(400);
      return res.end(JSON.stringify({ error: 'unsupported_action', allowed: ['lock'] }));
    }

    const child = spawn('rundll32.exe', ['user32.dll,LockWorkStation'], {
      windowsHide: true,
      shell: false,
      stdio: 'ignore',
    });
    child.once('error', err => {
      console.error('Lock command failed:', err.message);
      if (!res.headersSent) {
        res.writeHead(500);
        res.end(JSON.stringify({ error: 'lock_failed' }));
      }
    });
    child.once('spawn', () => {
      console.log(new Date().toISOString(), 'Authenticated lock command accepted');
      if (!res.headersSent) {
        res.writeHead(202);
        res.end(JSON.stringify({ ok: true, accepted: true, action: 'lock' }));
      }
    });
  });
});

server.listen(PORT, HOST, () => {
  console.log('RemoteUnlock agent listening on http://' + HOST + ':' + PORT);
  console.log('Keep this service private. Expose it only through a trusted HTTPS VPN relay such as Tailscale Serve.');
  console.log('Supported action: lock only. Windows sign-in/unlock is intentionally not exposed.');
});
server.on('error', err => {
  console.error('Agent server error:', err.message);
  process.exit(1);
});
