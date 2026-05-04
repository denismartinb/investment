const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { requireAuth } = require("../lib/auth");

const MONTHS = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
const PLAN_MONTH_ALIASES = [
  { index: 1, aliases: ["ene", "enero", "jan", "january"] },
  { index: 2, aliases: ["feb", "febrero", "february"] },
  { index: 3, aliases: ["mar", "marzo", "march"] },
  { index: 4, aliases: ["abr", "abril", "apr", "april"] },
  { index: 5, aliases: ["may", "mayo"] },
  { index: 6, aliases: ["jun", "junio", "june"] },
  { index: 7, aliases: ["jul", "julio", "july"] },
  { index: 8, aliases: ["ago", "agosto", "aug", "august"] },
  { index: 9, aliases: ["sep", "sept", "septiembre", "september"] },
  { index: 10, aliases: ["oct", "octubre", "october"] },
  { index: 11, aliases: ["nov", "noviembre", "november"] },
  { index: 12, aliases: ["dic", "diciembre", "dec", "december"] },
];

function parseDecimal(value) {
  if (value === null || value === undefined) {
    return 0;
  }
  if (typeof value === "number") {
    return value;
  }

  const cleaned = String(value)
    .replace(/\u00a0/g, "")
    .replace(/€/g, "")
    .replace(/%/g, "")
    .replace(/\./g, "")
    .replace(/,/g, ".")
    .trim();

  if (!cleaned) {
    return 0;
  }

  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
}

function formatDisplayDate(date) {
  return `${String(date.getUTCDate()).padStart(2, "0")} ${MONTHS[date.getUTCMonth()]} ${date.getUTCFullYear()}`;
}

function normalizeText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

function parseSnapshotDate(value) {
  if (!value) {
    throw new Error("Hay una fila sin fecha en la Google Sheet.");
  }

  const stringValue = String(value).trim();

  if (/^\d{2}\/\d{2}\/\d{4}$/.test(stringValue)) {
    const [day, month, year] = stringValue.split("/").map(Number);
    return new Date(Date.UTC(year, month - 1, day));
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(stringValue)) {
    return new Date(`${stringValue}T00:00:00Z`);
  }

  const parsed = new Date(stringValue);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`No se pudo interpretar la fecha "${stringValue}".`);
  }

  return new Date(Date.UTC(parsed.getFullYear(), parsed.getMonth(), parsed.getDate()));
}

function normalizeRows(rows) {
  return rows
    .filter((raw) => String(raw["Fecha"] || "").trim() && String(raw["Nombre"] || "").trim())
    .map((raw) => {
      const date = parseSnapshotDate(raw["Fecha"]);
      return {
        name: (raw["Nombre"] || "").trim(),
        date: date.toISOString().slice(0, 10),
        dateLabel: formatDisplayDate(date),
        type: (raw["Tipo Inversión"] || "").trim(),
        shares: parseDecimal(raw["Participaciones"]),
        unitPrice: parseDecimal(raw["Precio Participación"]),
        value: parseDecimal(raw["Valor"]),
        contribution: parseDecimal(raw["Aportación"]),
        profit: parseDecimal(raw["Beneficio"]),
        ter: parseDecimal(raw["TER"]),
        isin: (raw["ISIN"] || "").trim(),
      };
    });
}

function emptyContributionPlan(error = null) {
  return {
    yearLabel: null,
    months: [],
    assets: [],
    totalMonthly: 0,
    totalAnnual: 0,
    totalMonthlyEquity: 0,
    totalMonthlyFixedIncome: 0,
    averageMonthly: 0,
    assetCount: 0,
    error,
  };
}

function emptyProfilePayload(error = null) {
  return {
    fullName: "Denis Martín Barroso",
    salaryEvolution: [],
    totalIncomeAnnual: [],
    error,
  };
}

function findHeaderIndex(headers, aliases) {
  return headers.findIndex((header) => aliases.includes(normalizeText(header)));
}

function parseProfileIncome(values) {
  if (!values || values.length < 2) {
    return [];
  }

  const headers = values[0].map((header) => String(header || "").trim());
  const yearIndex = findHeaderIndex(headers, ["ano", "año", "year"]);
  const incomeIndex = findHeaderIndex(headers, ["ingresos totales", "ingresos", "total ingresos", "total"]);

  if (yearIndex === -1 || incomeIndex === -1) {
    throw new Error("La pestaña Evolucion ingresos no contiene columnas reconocibles de año e ingresos totales.");
  }

  return values
    .slice(1)
    .filter((row) => row.some((cell) => String(cell || "").trim() !== ""))
    .map((row) => ({
      year: Number(String(row[yearIndex] || "").trim()),
      totalIncome: parseDecimal(row[incomeIndex]),
    }))
    .filter((point) => Number.isFinite(point.year) && point.year > 0 && Number.isFinite(point.totalIncome))
    .sort((left, right) => left.year - right.year);
}

function parseProfileSalary(values) {
  if (!values || values.length < 2) {
    return [];
  }

  const headers = values[0].map((header) => String(header || "").trim());
  const yearIndex = findHeaderIndex(headers, ["ano", "año", "year"]);
  const grossSalaryIndex = findHeaderIndex(headers, ["salario bruto", "salario", "gross salary"]);
  const bonusIndex = findHeaderIndex(headers, ["bonus", "variable"]);
  const topPerformerIndex = findHeaderIndex(headers, ["top performer"]);
  const totalIndex = findHeaderIndex(headers, ["total", "compensacion total", "compensación total"]);

  if (yearIndex === -1 || (grossSalaryIndex === -1 && totalIndex === -1)) {
    throw new Error("La pestaña Evolucion salario no contiene columnas reconocibles de año y salario.");
  }

  return values
    .slice(1)
    .filter((row) => row.some((cell) => String(cell || "").trim() !== ""))
    .map((row) => {
      const grossSalary = grossSalaryIndex >= 0 ? parseDecimal(row[grossSalaryIndex]) : 0;
      const bonus = bonusIndex >= 0 ? parseDecimal(row[bonusIndex]) : 0;
      const topPerformer = topPerformerIndex >= 0 ? parseDecimal(row[topPerformerIndex]) : 0;
      const total = totalIndex >= 0 ? parseDecimal(row[totalIndex]) : 0;
      const computedTotal = total || grossSalary + bonus + topPerformer || grossSalary;
      return {
        year: Number(String(row[yearIndex] || "").trim()),
        grossSalary,
        bonus,
        topPerformer,
        salary: computedTotal,
      };
    })
    .filter((point) => Number.isFinite(point.year) && point.year > 0 && Number.isFinite(point.salary))
    .sort((left, right) => left.year - right.year);
}

function parseProfilePayload(incomeValues, salaryValues) {
  return {
    fullName: "Denis Martín Barroso",
    totalIncomeAnnual: parseProfileIncome(incomeValues),
    salaryEvolution: parseProfileSalary(salaryValues),
    error: null,
  };
}

function getPlanMonthMeta(header) {
  const normalized = normalizeText(header);
  if (!normalized) {
    return null;
  }

  const numericYearMonth = normalized.match(/^(\d{4})[-/](\d{1,2})$/);
  if (numericYearMonth) {
    const year = numericYearMonth[1];
    const monthIndex = Number(numericYearMonth[2]);
    if (monthIndex >= 1 && monthIndex <= 12) {
      return { monthIndex, year };
    }
  }

  const numericMonthYear = normalized.match(/^(\d{1,2})[-/](\d{4})$/);
  if (numericMonthYear) {
    const monthIndex = Number(numericMonthYear[1]);
    const year = numericMonthYear[2];
    if (monthIndex >= 1 && monthIndex <= 12) {
      return { monthIndex, year };
    }
  }

  const parts = normalized.split(/[^a-z0-9]+/).filter(Boolean);
  const year = parts.find((part) => /^\d{4}$/.test(part)) || null;
  for (const month of PLAN_MONTH_ALIASES) {
    if (month.aliases.some((alias) => parts.includes(alias) || normalized === alias)) {
      return { monthIndex: month.index, year };
    }
  }
  return null;
}

function parseContributionPlan(values) {
  if (!values || values.length < 2) {
    return emptyContributionPlan();
  }

  const headers = values[0].map((header) => String(header || "").trim());
  const assetHeaderIndex = headers.findIndex((header) => {
    const normalized = normalizeText(header);
    return ["nombre", "activo", "asset", "inversion", "vehiculo"].includes(normalized);
  });
  const typeHeaderIndex = headers.findIndex((header) => {
    const normalized = normalizeText(header);
    return ["tipo", "tipo inversion", "tipo de inversion", "tipo activo", "tipo de activo"].includes(normalized);
  });
  const allocationHeaderIndex = headers.findIndex((header) => normalizeText(header) === "asset allocation");
  const monthlyHeaderIndex = headers.findIndex((header) => {
    const normalized = normalizeText(header);
    return ["aportacion mensual", "transferencia mensual", "mensual"].includes(normalized);
  });
  const annualHeaderIndex = headers.findIndex((header) => {
    const normalized = normalizeText(header);
    return ["aportacion anual", "anual"].includes(normalized);
  });
  const monthlyEquityHeaderIndex = headers.findIndex((header) => normalizeText(header) === "renta variable");
  const monthlyFixedHeaderIndex = headers.findIndex((header) => normalizeText(header) === "renta fija");

  if (monthlyHeaderIndex === -1 && annualHeaderIndex === -1) {
    return emptyContributionPlan("La pestaña Plan aportaciones no contiene columnas de aportación mensual o anual reconocibles.");
  }

  const fallbackAssetIndex = headers.findIndex((_, index) => index !== typeHeaderIndex && index !== monthlyHeaderIndex && index !== annualHeaderIndex);
  const assetIndex = assetHeaderIndex >= 0 ? assetHeaderIndex : Math.max(fallbackAssetIndex, 0);

  const assets = values
    .slice(1)
    .filter((row) => row.some((cell) => String(cell || "").trim() !== ""))
    .map((row) => {
      const rawName = String(row[assetIndex] || "").trim();
      const normalizedName = normalizeText(rawName);
      if (!rawName || ["total", "totales", "resumen", "suma"].includes(normalizedName)) {
        return null;
      }
      const monthlyAmount = monthlyHeaderIndex >= 0 ? parseDecimal(row[monthlyHeaderIndex]) : 0;
      const annualCell = annualHeaderIndex >= 0 ? parseDecimal(row[annualHeaderIndex]) : 0;
      const annualTotal = annualCell || monthlyAmount * 12;
      const monthlyEquityAmount = monthlyEquityHeaderIndex >= 0 ? parseDecimal(row[monthlyEquityHeaderIndex]) : 0;
      const monthlyFixedAmount = monthlyFixedHeaderIndex >= 0 ? parseDecimal(row[monthlyFixedHeaderIndex]) : 0;
      return {
        name: rawName,
        type: typeHeaderIndex >= 0 ? String(row[typeHeaderIndex] || "").trim() : "",
        allocation: allocationHeaderIndex >= 0 ? String(row[allocationHeaderIndex] || "").trim() : "",
        monthlyAmount: Number(monthlyAmount.toFixed(2)),
        annualTotal: Number(annualTotal.toFixed(2)),
        monthlyEquityAmount: Number(monthlyEquityAmount.toFixed(2)),
        monthlyFixedAmount: Number(monthlyFixedAmount.toFixed(2)),
      };
    })
    .filter((asset) => asset && (asset.monthlyAmount !== 0 || asset.annualTotal !== 0))
    .sort((left, right) => right.annualTotal - left.annualTotal);

  const totalMonthly = assets.reduce((sum, asset) => sum + asset.monthlyAmount, 0);
  const totalAnnual = assets.reduce((sum, asset) => sum + asset.annualTotal, 0);
  const totalMonthlyEquity = assets.reduce((sum, asset) => sum + asset.monthlyEquityAmount, 0);
  const totalMonthlyFixedIncome = assets.reduce((sum, asset) => sum + asset.monthlyFixedAmount, 0);

  return {
    yearLabel: null,
    months: [],
    assets,
    totalMonthly: Number(totalMonthly.toFixed(2)),
    totalAnnual: Number(totalAnnual.toFixed(2)),
    totalMonthlyEquity: Number(totalMonthlyEquity.toFixed(2)),
    totalMonthlyFixedIncome: Number(totalMonthlyFixedIncome.toFixed(2)),
    averageMonthly: Number(totalMonthly.toFixed(2)),
    assetCount: assets.length,
    error: null,
  };
}

function buildPayload(rows, sourceFile, contributionPlan = emptyContributionPlan(), profile = emptyProfilePayload()) {
  const snapshots = {};

  for (const row of rows) {
    if (!snapshots[row.date]) {
      snapshots[row.date] = [];
    }
    snapshots[row.date].push(row);
  }

  const dates = Object.keys(snapshots).sort();
  const series = dates.map((date) => {
    const positions = snapshots[date];
    const grossAssets = positions.reduce((sum, item) => sum + (item.value > 0 ? item.value : 0), 0);
    const liabilities = positions.reduce((sum, item) => sum + (item.value < 0 ? item.value : 0), 0);
    const contribution = positions.reduce((sum, item) => sum + item.contribution, 0);
    const profit = positions.reduce((sum, item) => sum + item.profit, 0);
    return {
      date,
      label: formatDisplayDate(new Date(`${date}T00:00:00Z`)),
      grossAssets: Number(grossAssets.toFixed(2)),
      liabilities: Number(liabilities.toFixed(2)),
      netWorth: Number((grossAssets + liabilities).toFixed(2)),
      contribution: Number(contribution.toFixed(2)),
      profit: Number(profit.toFixed(2)),
    };
  });

  const latestDate = dates[dates.length - 1] || null;
  const latestPositions = latestDate ? [...(snapshots[latestDate] || [])].sort((a, b) => b.value - a.value) : [];

  return {
    generatedAt: new Date().toISOString().slice(0, 16).replace("T", " "),
    sourceFile,
    series,
    snapshots,
    dates,
    latestDate,
    latestPositions,
    contributionPlan,
    profile,
  };
}

function mapTable(values) {
  if (!values || values.length < 2) {
    throw new Error("La hoja no tiene suficientes filas para construir el dashboard.");
  }

  const headers = values[0].map((header) => String(header || "").trim());
  const requiredHeaders = ["Nombre", "Fecha", "Tipo Inversión", "Valor", "Aportación", "Beneficio"];
  const missingHeaders = requiredHeaders.filter((header) => !headers.includes(header));

  if (missingHeaders.length > 0) {
    throw new Error(`Faltan columnas requeridas en la Google Sheet: ${missingHeaders.join(", ")}`);
  }

  return values
    .slice(1)
    .filter((row) => row.some((cell) => String(cell || "").trim() !== ""))
    .map((row) => {
      const entry = {};
      headers.forEach((header, index) => {
        if (header) {
          entry[header] = row[index] || "";
        }
      });
      return entry;
    });
}

function base64UrlEncode(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

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

function normalizeRange(range) {
  const value = String(range || "").trim();
  return value;
}

function getConfig() {
  loadLocalEnv();

  const config = {
    spreadsheetId: process.env.GOOGLE_SHEETS_SPREADSHEET_ID,
    sheetName: process.env.GOOGLE_SHEETS_SHEET_NAME,
    range: process.env.GOOGLE_SHEETS_RANGE || process.env.GOOGLE_SHEETS_SHEET_NAME,
    planSheetName: process.env.GOOGLE_SHEETS_PLAN_SHEET_NAME || "Plan aportaciones",
    planRange: process.env.GOOGLE_SHEETS_PLAN_RANGE || "'Plan aportaciones'!A:ZZ",
    profileIncomeSheetName: process.env.GOOGLE_SHEETS_PROFILE_INCOME_SHEET_NAME || "Evolucion ingresos",
    profileIncomeRange: process.env.GOOGLE_SHEETS_PROFILE_INCOME_RANGE || "'Evolucion ingresos'!A:Z",
    profileSalarySheetName: process.env.GOOGLE_SHEETS_PROFILE_SALARY_SHEET_NAME || "Evolucion salario",
    profileSalaryRange: process.env.GOOGLE_SHEETS_PROFILE_SALARY_RANGE || "'Evolucion salario'!A:Z",
    clientEmail: process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
    privateKey: process.env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY?.replace(/\\n/g, "\n"),
  };

  const missing = [
    ["GOOGLE_SHEETS_SPREADSHEET_ID", config.spreadsheetId],
    ["GOOGLE_SHEETS_SHEET_NAME", config.sheetName],
    ["GOOGLE_SERVICE_ACCOUNT_EMAIL", config.clientEmail],
    ["GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY", config.privateKey],
  ]
    .filter(([, value]) => !value)
    .map(([name]) => name);

  if (missing.length > 0) {
    throw new Error(`Faltan variables de entorno: ${missing.join(", ")}`);
  }

  return config;
}

async function getAccessToken() {
  const { clientEmail, privateKey } = getConfig();
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 3600;

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/spreadsheets.readonly",
    aud: "https://oauth2.googleapis.com/token",
    exp: expiresAt,
    iat: issuedAt,
  };

  const unsignedToken = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(claimSet))}`;
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(unsignedToken);
  signer.end();
  const signature = signer.sign(privateKey);
  const jwt = `${unsignedToken}.${base64UrlEncode(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`No se pudo obtener el access token (${response.status}).`);
  }

  const payload = await response.json();
  if (!payload.access_token) {
    throw new Error("La respuesta de OAuth no incluye access_token.");
  }

  return payload.access_token;
}

async function getSheetValues({ spreadsheetId, range, sheetName }, accessToken) {
  const normalizedRange = normalizeRange(range);
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(spreadsheetId)}/values/${encodeURIComponent(normalizedRange)}?valueRenderOption=FORMATTED_VALUE&dateTimeRenderOption=FORMATTED_STRING`;

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Google Sheets API respondió ${response.status}: ${detail}`);
  }

  const payload = await response.json();
  return {
    values: payload.values || [],
    sourceFile: `Google Sheets · ${sheetName}`,
  };
}

async function getPortfolioPayload() {
  const config = getConfig();
  const accessToken = await getAccessToken();
  const { values, sourceFile } = await getSheetValues(
    { spreadsheetId: config.spreadsheetId, range: config.range, sheetName: config.sheetName },
    accessToken,
  );
  const tableRows = mapTable(values);
  const normalized = normalizeRows(tableRows);

  let contributionPlan = emptyContributionPlan();
  try {
    const planSheet = await getSheetValues(
      { spreadsheetId: config.spreadsheetId, range: config.planRange, sheetName: config.planSheetName },
      accessToken,
    );
    contributionPlan = parseContributionPlan(planSheet.values);
  } catch (error) {
    contributionPlan = emptyContributionPlan(error.message);
  }

  let profile = emptyProfilePayload();
  try {
    const [incomeSheet, salarySheet] = await Promise.all([
      getSheetValues(
        { spreadsheetId: config.spreadsheetId, range: config.profileIncomeRange, sheetName: config.profileIncomeSheetName },
        accessToken,
      ),
      getSheetValues(
        { spreadsheetId: config.spreadsheetId, range: config.profileSalaryRange, sheetName: config.profileSalarySheetName },
        accessToken,
      ),
    ]);
    profile = parseProfilePayload(incomeSheet.values, salarySheet.values);
  } catch (error) {
    profile = emptyProfilePayload(error.message);
  }

  return buildPayload(normalized, sourceFile, contributionPlan, profile);
}

async function handler(req, res) {
  if (!requireAuth(req, res, { api: true })) {
    return;
  }

  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  try {
    const payload = await getPortfolioPayload();
    res.statusCode = 200;
    res.end(JSON.stringify(payload));
  } catch (error) {
    res.statusCode = 500;
    res.end(
      JSON.stringify({
        error: "No se pudo leer la Google Sheet privada.",
        detail: error.message,
      }),
    );
  }
}

module.exports = handler;
module.exports.getPortfolioPayload = getPortfolioPayload;
