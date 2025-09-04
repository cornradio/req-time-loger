// Minimal proxy server to forward requests and allow cookie overrides
// Usage: npm i express node-fetch@3 && node proxy.js
import express from 'express';
import fetch from 'node-fetch';

const app = express();

// Basic CORS for local use. Adjust Origin to your page's origin if needed.
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-CSRF-Token, X-Requested-With, *');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use(express.json({ limit: '20mb' }));

app.post('/proxy', async (req, res) => {
  try {
    const { url, method = 'GET', headers = {}, body, cookieOverride } = req.body || {};
    if (!url) return res.status(400).json({ error: 'url required' });

    const outHeaders = { ...headers };
    if (cookieOverride) {
      outHeaders['cookie'] = cookieOverride;
    }

    const upstream = await fetch(url, {
      method,
      headers: outHeaders,
      body: body == null ? undefined : (typeof body === 'string' ? body : JSON.stringify(body)),
      redirect: 'manual',
    });

    const buf = await upstream.arrayBuffer();
    res.status(upstream.status);
    const ct = upstream.headers.get('content-type');
    if (ct) res.setHeader('content-type', ct);
    res.setHeader('x-proxy-upstream-status', String(upstream.status));
    res.send(Buffer.from(buf));
  } catch (e) {
    res.status(502).json({ error: String(e) });
  }
});

const PORT = process.env.PORT || 8787;
app.listen(PORT, () => console.log(`Proxy listening on http://localhost:${PORT}`));


