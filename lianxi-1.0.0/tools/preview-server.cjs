const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', 'build', 'web');
const port = Number(process.env.PREVIEW_PORT || 8765);

http
  .createServer((request, response) => {
    let pathname = decodeURIComponent(request.url.split('?')[0]);
    if (pathname === '/') pathname = '/index.html';
    const file = path.resolve(root, `.${pathname}`);
    if (!file.startsWith(root)) {
      response.writeHead(403).end();
      return;
    }

    fs.readFile(file, (error, content) => {
      if (error) {
        fs.readFile(path.join(root, 'index.html'), (fallbackError, fallback) => {
          response
            .writeHead(fallbackError ? 404 : 200, {
              'Cache-Control': 'no-store, max-age=0',
              'Content-Type': 'text/html; charset=utf-8',
            })
            .end(fallback);
        });
        return;
      }
      response
        .writeHead(200, {
          'Cache-Control': 'no-store, max-age=0',
        })
        .end(content);
    });
  })
  .listen(port, '127.0.0.1');
