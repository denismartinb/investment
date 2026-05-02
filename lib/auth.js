const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const COOKIE_NAME = "investment_session";
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30;

function loadLocalEnv() {
  const envPath = path.join(process.cwd(), ".env.local");
  if (!fs.existsSync(envPath)) {
    return;
  }

  const content = fs.readFileSync(envPath, "utf8");
  for (const line of content.split(/\r?\n/)) {
    if (!line || line.trim().startsWith("#")) {
      continue;
    }
    const separator = line.indexOf("=");
    if (separator === -1) {
      continue;
    }
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

function base64UrlEncode(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function base64UrlDecode(input) {
  const normalized = String(input).replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + padding, "base64").toString("utf8");
}

function getAuthConfig() {
  loadLocalEnv();
  const config = {
    username: process.env.DASHBOARD_USERNAME,
    password: process.env.DASHBOARD_PASSWORD,
    secret: process.env.DASHBOARD_AUTH_SECRET,
  };

  const missing = Object.entries({
    DASHBOARD_USERNAME: config.username,
    DASHBOARD_PASSWORD: config.password,
    DASHBOARD_AUTH_SECRET: config.secret,
  })
    .filter(([, value]) => !value)
    .map(([name]) => name);

  if (missing.length) {
    throw new Error(`Faltan variables de autenticación: ${missing.join(", ")}`);
  }

  return config;
}

function parseCookies(req) {
  const header = req.headers?.cookie || "";
  return header.split(/;\s*/).filter(Boolean).reduce((acc, entry) => {
    const separator = entry.indexOf("=");
    if (separator === -1) {
      return acc;
    }
    const key = decodeURIComponent(entry.slice(0, separator).trim());
    const value = decodeURIComponent(entry.slice(separator + 1).trim());
    acc[key] = value;
    return acc;
  }, {});
}

function signPayload(payload, secret) {
  return crypto.createHmac("sha256", secret).update(payload).digest("base64url");
}

function createSessionToken(username) {
  const { secret } = getAuthConfig();
  const payload = base64UrlEncode(JSON.stringify({
    username,
    exp: Date.now() + SESSION_TTL_MS,
  }));
  const signature = signPayload(payload, secret);
  return `${payload}.${signature}`;
}

function verifySessionToken(token) {
  if (!token || !token.includes(".")) {
    return null;
  }
  const { secret, username } = getAuthConfig();
  const [payload, signature] = token.split(".");
  if (!payload || !signature) {
    return null;
  }
  const expected = signPayload(payload, secret);
  const left = Buffer.from(signature);
  const right = Buffer.from(expected);
  if (left.length !== right.length || !crypto.timingSafeEqual(left, right)) {
    return null;
  }

  let parsed;
  try {
    parsed = JSON.parse(base64UrlDecode(payload));
  } catch {
    return null;
  }

  if (!parsed || parsed.username !== username || Number(parsed.exp || 0) < Date.now()) {
    return null;
  }

  return parsed;
}

function isAuthenticatedRequest(req) {
  const cookies = parseCookies(req);
  return Boolean(verifySessionToken(cookies[COOKIE_NAME]));
}

function isSecureRequest(req) {
  const forwarded = String(req.headers?.["x-forwarded-proto"] || "").toLowerCase();
  return forwarded.includes("https") || Boolean(req.socket && req.socket.encrypted);
}

function serializeCookie(name, value, options = {}) {
  const parts = [`${name}=${value}`];
  if (options.maxAge !== undefined) {
    parts.push(`Max-Age=${options.maxAge}`);
  }
  parts.push(`Path=${options.path || "/"}`);
  if (options.httpOnly !== false) {
    parts.push("HttpOnly");
  }
  parts.push(`SameSite=${options.sameSite || "Lax"}`);
  if (options.secure) {
    parts.push("Secure");
  }
  return parts.join("; ");
}

function setSessionCookie(req, res, username) {
  const cookie = serializeCookie(COOKIE_NAME, createSessionToken(username), {
    maxAge: Math.floor(SESSION_TTL_MS / 1000),
    secure: isSecureRequest(req),
  });
  res.setHeader("Set-Cookie", cookie);
}

function clearSessionCookie(req, res) {
  const cookie = serializeCookie(COOKIE_NAME, "", {
    maxAge: 0,
    secure: isSecureRequest(req),
  });
  res.setHeader("Set-Cookie", cookie);
}

async function readRequestBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

function parseRequestBody(body, contentType = "") {
  if (!body) {
    return {};
  }
  if (contentType.includes("application/json")) {
    try {
      return JSON.parse(body);
    } catch {
      return {};
    }
  }
  const params = new URLSearchParams(body);
  return Object.fromEntries(params.entries());
}

function redirectToLogin(req, res) {
  const url = new URL(req.url || "/", "http://local");
  const next = url.pathname + (url.search || "");
  const destination = `/login?next=${encodeURIComponent(next)}`;
  res.statusCode = 302;
  res.setHeader("Location", destination);
  res.end();
}

function requireAuth(req, res, { api = false } = {}) {
  if (isAuthenticatedRequest(req)) {
    return true;
  }
  if (api) {
    res.statusCode = 401;
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.end(JSON.stringify({ error: "No autorizado" }));
    return false;
  }
  redirectToLogin(req, res);
  return false;
}

module.exports = {
  COOKIE_NAME,
  clearSessionCookie,
  getAuthConfig,
  isAuthenticatedRequest,
  parseRequestBody,
  readRequestBody,
  requireAuth,
  setSessionCookie,
};
