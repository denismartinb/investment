const fs = require("node:fs");
const path = require("node:path");
const http = require("node:http");
const portfolioHandler = require("./api/portfolio");
const dashboardHandler = require("./api/dashboard");
const profileHandler = require("./api/profile");
const loginHandler = require("./api/auth/login");
const logoutHandler = require("./api/auth/logout");

const HOST = "127.0.0.1";
const PORT = Number(process.env.PORT || 3001);
const ROOT = process.cwd();

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".ico": "image/x-icon",
};

function serveFile(res, targetPath) {
  if (!fs.existsSync(targetPath) || fs.statSync(targetPath).isDirectory()) {
    res.statusCode = 404;
    res.end("Not found");
    return;
  }

  const extension = path.extname(targetPath).toLowerCase();
  res.setHeader("Content-Type", mimeTypes[extension] || "application/octet-stream");
  fs.createReadStream(targetPath).pipe(res);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);

  if (url.pathname === "/api/portfolio") {
    await portfolioHandler(req, res);
    return;
  }

  if (url.pathname === "/api/auth/login") {
    await loginHandler(req, res);
    return;
  }

  if (url.pathname === "/api/auth/logout") {
    await logoutHandler(req, res);
    return;
  }

  if (url.pathname === "/" || url.pathname === "/investment_dashboard.html") {
    await dashboardHandler(req, res);
    return;
  }

  if (url.pathname === "/profile" || url.pathname === "/profile.html") {
    await profileHandler(req, res);
    return;
  }

  if (url.pathname === "/login" || url.pathname === "/login.html") {
    serveFile(res, path.join(ROOT, "login.html"));
    return;
  }

  const safePath = path.normalize(url.pathname).replace(/^(\.\.[/\\])+/, "");
  serveFile(res, path.join(ROOT, safePath));
});

server.listen(PORT, HOST, () => {
  console.log(`Dashboard local disponible en http://${HOST}:${PORT}`);
});
