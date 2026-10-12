import http from 'node:http';
import { readFile } from 'node:fs/promises';
const port = Number(process.env.PORT || 8791);
http.createServer(async (req, res) => {
  const name = new URL(req.url, 'http://localhost').pathname;
  if (name === '/favicon.ico') { res.writeHead(204).end(); return; }
  if (!['/', '/index.html', '/page.js', '/page.js.map'].includes(name)) { res.writeHead(404).end(); return; }
  try { const data = await readFile(new URL('./dist/' + (name === '/' ? 'index.html' : name.slice(1)), import.meta.url)); res.setHeader('Content-Type', name.endsWith('.js') ? 'text/javascript' : name.endsWith('.map') ? 'application/json' : 'text/html; charset=utf-8'); res.end(data); }
  catch { res.writeHead(500).end('Run node build.mjs first'); }
}).listen(port, '127.0.0.1', () => console.log(`Physics lab: http://127.0.0.1:${port}`));
