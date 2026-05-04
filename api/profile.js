const fs = require("node:fs");
const path = require("node:path");
const { requireAuth } = require("../lib/auth");

module.exports = async function handler(req, res) {
  if (!requireAuth(req, res, { api: false })) {
    return;
  }

  const filePath = path.join(process.cwd(), "profile.html");
  if (!fs.existsSync(filePath)) {
    res.statusCode = 404;
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.end("Perfil no encontrado");
    return;
  }

  res.statusCode = 200;
  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  fs.createReadStream(filePath).pipe(res);
};
