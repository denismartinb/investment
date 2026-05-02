const { clearSessionCookie } = require("../../lib/auth");

module.exports = async function handler(req, res) {
  clearSessionCookie(req, res);
  const acceptsJson = String(req.headers.accept || "").includes("application/json");
  if (acceptsJson || req.method === "POST") {
    res.statusCode = 200;
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.end(JSON.stringify({ ok: true }));
    return;
  }
  res.statusCode = 302;
  res.setHeader("Location", "/login");
  res.end();
};
