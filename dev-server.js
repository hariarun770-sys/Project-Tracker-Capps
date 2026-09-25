const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf'
};

const server = http.createServer((req, res) => {
  // Handle CORS Preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    res.end();
    return;
  }

  // API Endpoint: File Upload
  if (req.method === 'POST' && req.url === '/api/upload') {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { type, fileName, content } = data;

        if (!fileName || !content) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Missing fileName or content' }));
          return;
        }

        const targetFolder = (type === 'scope') ? 'scope document' : 'Incubator Weekly update';
        const targetDir = path.join(__dirname, targetFolder);
        if (!fs.existsSync(targetDir)) {
          fs.mkdirSync(targetDir, { recursive: true });
        }

        const cleanFileName = fileName.replace(/[^a-zA-Z0-9_\-\.]/g, '_');
        const savePath = path.join(targetDir, cleanFileName);

        // Ensure exporter scripts are present in uploaded HTML
        let finalContent = content;
        if (cleanFileName.endsWith('.html') && !finalContent.includes('exporter.js')) {
          const scripts = `
  <!-- Project Tracker Exporter & High-Resolution JPG Engine -->
  <script src="../assets/js/html2canvas.min.js"></script>
  <script src="../assets/js/exporter.js"></script>
</body>`;
          finalContent = finalContent.replace('</body>', scripts);
        }

        fs.writeFileSync(savePath, finalContent, 'utf8');
        const relativeUrl = `${targetFolder}/${cleanFileName}`;

        console.log(`[Upload] Saved ${type} document: ${relativeUrl}`);

        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(JSON.stringify({
          success: true,
          fileName: cleanFileName,
          url: relativeUrl
        }));
      } catch (err) {
        console.error('[Upload Error]', err);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // Static File Serving
  let reqUrl = decodeURIComponent(req.url.split('?')[0]);
  if (reqUrl === '/') reqUrl = '/index.html';

  const filePath = path.join(__dirname, reqUrl);

  if (!filePath.startsWith(__dirname)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('403 Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found: ' + reqUrl);
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache'
    });

    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, () => {
  console.log(`\n🚀 Project Tracker is live at: http://localhost:${PORT}`);
  console.log(`Open http://localhost:${PORT} in your browser to view the portal.\n`);
});
