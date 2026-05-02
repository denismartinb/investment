const { getAuthConfig, parseRequestBody, readRequestBody, setSessionCookie } = require("../../lib/auth");

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    res.statusCode = 405;
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.end(JSON.stringify({ error: "Método no permitido" }));
    return;
  }

  const body = await readRequestBody(req);
  const contentType = String(req.headers["content-type"] || "");
  const payload = parseRequestBody(body, contentType);
  const username = String(payload.username || "").trim();
  const password = String(payload.password || "");
  const next = String(payload.next || "/");
  const config = getAuthConfig();

  if (username !== config.username || password !== config.password) {
    res.statusCode = 401;
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.end(JSON.stringify({ error: "Credenciales incorrectas" }));
    return;
  }

  setSessionCookie(req, res, username);
  res.statusCode = 200;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify({ ok: true, next: next.startsWith("/") ? next : "/" }));
};
