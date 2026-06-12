const PROFILE_PHOTO_SRC = 'assets/profile-photo.png';
const state = {
  hideSensitiveValues: false,
  theme: 'dark',
};

function formatCurrency(value) {
  return new Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(value);
}

function formatProfileCurrency(value) {
  if (!Number.isFinite(value)) return '-';
  return state.hideSensitiveValues ? '••••••' : formatCurrency(value);
}

function formatProfileAxisCurrency(value) {
  if (state.hideSensitiveValues) return '•••';
  const abs = Math.abs(value);
  if (abs >= 1000) {
    return `${new Intl.NumberFormat('es-ES', { maximumFractionDigits: 0 }).format(Math.round(value / 1000))} mil €`;
  }
  return formatCurrency(value);
}

function getChartTheme() {
  const isLight = document.documentElement.dataset.theme === 'light';
  return isLight
    ? {
        grid: 'rgba(43,70,97,0.14)',
        axis: 'rgba(43,70,97,0.74)',
        axisSoft: 'rgba(43,70,97,0.58)',
        empty: 'rgba(43,70,97,0.72)',
      }
    : {
        grid: 'rgba(255,255,255,0.08)',
        axis: 'rgba(214,226,238,0.68)',
        axisSoft: 'rgba(214,226,238,0.52)',
        empty: 'rgba(214,226,238,0.68)',
      };
}

function buildTicks(maxValue, count) {
  const safeMax = Math.max(maxValue, 1);
  return Array.from({ length: count + 1 }, (_, index) => (safeMax / count) * index);
}

function sampleProfileYears(years) {
  if (years.length <= 4) return years;
  const maxLabels = years.length > 10 ? 5 : years.length > 7 ? 4 : 5;
  const step = Math.max(Math.ceil(years.length / maxLabels), 1);
  return years.filter((year, index) => index === 0 || index === years.length - 1 || index % step === 0);
}

function applyTheme(theme) {
  const normalizedTheme = theme === 'light' ? 'light' : 'dark';
  state.theme = normalizedTheme;
  document.documentElement.dataset.theme = normalizedTheme;
  try {
    localStorage.setItem('investment-theme', normalizedTheme);
  } catch {}
  const button = document.getElementById('themeToggleButton');
  const icon = document.getElementById('themeToggleIcon');
  const label = document.getElementById('themeToggleLabel');
  const isLight = normalizedTheme === 'light';
  if (button) {
    button.setAttribute('aria-pressed', isLight ? 'true' : 'false');
    button.setAttribute('title', isLight ? 'Cambiar a modo oscuro' : 'Cambiar a modo claro');
  }
  if (icon) icon.textContent = isLight ? '☀' : '☾';
  if (label) label.textContent = isLight ? 'Modo claro' : 'Modo oscuro';
}

function applyPrivacyPreference(hidden) {
  state.hideSensitiveValues = Boolean(hidden);
  try {
    localStorage.setItem('investment-hide-sensitive', hidden ? 'true' : 'false');
  } catch {}
  const button = document.getElementById('privacyToggleButton');
  const label = document.getElementById('privacyToggleLabel');
  if (button) {
    button.setAttribute('aria-pressed', hidden ? 'true' : 'false');
    button.setAttribute('title', hidden ? 'Mostrar cifras sensibles' : 'Ocultar cifras sensibles');
  }
  if (label) label.textContent = hidden ? 'Mostrar cifras' : 'Ocultar cifras';
}

function closeTooltips() {
  document.querySelectorAll('#incomeTooltip, #salaryTooltip').forEach((node) => node.classList.remove('is-visible'));
}

function setTooltip(tooltip, anchor, shell, lines) {
  tooltip.innerHTML = `
    <strong>${lines[0]}</strong>
    ${lines.slice(1).map((line) => `
      <div class="chart-tooltip-line">
        <span class="chart-tooltip-label">${line.label}</span>
        <span>${line.value}</span>
      </div>
    `).join('')}
  `;
  const shellRect = shell.getBoundingClientRect();
  const anchorRect = anchor.getBoundingClientRect();
  const tooltipWidth = Math.min(280, Math.max(176, tooltip.offsetWidth || 176));
  const centeredX = anchorRect.left - shellRect.left + anchorRect.width / 2 - tooltipWidth / 2;
  const maxLeft = Math.max(shellRect.width - tooltipWidth - 12, 12);
  const left = Math.max(12, Math.min(centeredX, maxLeft));
  const preferredTop = anchorRect.top - shellRect.top + anchorRect.height + 12;
  const maxTop = Math.max(shellRect.height - (tooltip.offsetHeight || 120) - 12, 12);
  const top = Math.max(12, Math.min(preferredTop, maxTop));
  tooltip.style.left = `${left}px`;
  tooltip.style.top = `${top}px`;
  tooltip.classList.add('is-visible');
}

function getVisibleProfileData(profile) {
  const incomePoints = (profile.totalIncomeAnnual || [])
    .map((item) => ({ year: Number(item.year), totalIncome: Number(item.totalIncome || 0) }))
    .filter((item) => Number.isFinite(item.year) && item.year > 0 && Number.isFinite(item.totalIncome))
    .sort((a, b) => a.year - b.year);
  const salaryPoints = (profile.salaryEvolution || [])
    .map((item) => ({
      year: Number(item.year),
      grossSalary: Number(item.grossSalary || 0),
      bonus: Number(item.bonus || 0),
      topPerformer: Number(item.topPerformer || 0),
      salary: Number(item.salary || 0),
    }))
    .filter((item) => Number.isFinite(item.year) && item.year > 0 && Number.isFinite(item.salary))
    .sort((a, b) => a.year - b.year);
  const maxIncomeYear = incomePoints.reduce((max, item) => Math.max(max, item.year), 0);
  return {
    fullName: profile.fullName || 'Denis Martín Barroso',
    error: profile.error || null,
    incomePoints: maxIncomeYear ? incomePoints.filter((item) => item.year <= maxIncomeYear) : incomePoints,
    salaryPoints,
  };
}

function renderIncomeChart(data) {
  const shell = document.getElementById('incomeChartShell');
  const svg = document.getElementById('incomeChart');
  const tooltip = document.getElementById('incomeTooltip');
  const incomeMap = new Map(data.incomePoints.map((item) => [item.year, item]));
  const salaryMap = new Map(data.salaryPoints.map((item) => [item.year, item]));
  const years = Array.from(new Set([...incomeMap.keys(), ...salaryMap.keys()])).sort((a, b) => a - b);
  if (!years.length) {
    svg.innerHTML = `<text x="50%" y="50%" text-anchor="middle" fill="${getChartTheme().empty}" font-size="16">Sin datos suficientes</text>`;
    return;
  }
  const theme = getChartTheme();
  const width = 960;
  const height = 336;
  const padding = { top: 18, right: 20, bottom: 34, left: 84 };
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;
  const xStep = years.length === 1 ? 0 : chartWidth / (years.length - 1);
  const maxValue = Math.max(...data.incomePoints.map((item) => item.totalIncome), ...data.salaryPoints.map((item) => item.salary), 1);
  const domainMax = maxValue * 1.16;
  const y = (value) => padding.top + chartHeight - (value / domainMax) * chartHeight;
  const x = (year) => padding.left + (years.length === 1 ? chartWidth / 2 : years.indexOf(year) * xStep);
  const yTicks = buildTicks(domainMax, 4);
  const sampledYears = sampleProfileYears(years);
  const barWidth = Math.min(42, Math.max(chartWidth / Math.max(years.length * 1.9, 1), 18));
  const grid = yTicks.map((tick) => `
    <g>
      <line x1="${padding.left}" y1="${y(tick).toFixed(2)}" x2="${width - padding.right}" y2="${y(tick).toFixed(2)}" stroke="${theme.grid}" stroke-width="1" stroke-dasharray="4 6"></line>
      <text x="${padding.left - 12}" y="${(y(tick) + 4).toFixed(2)}" text-anchor="end" fill="${theme.axis}" font-size="11">${formatProfileAxisCurrency(tick)}</text>
    </g>
  `).join('');
  const xLabels = sampledYears.map((year) => `<text x="${x(year).toFixed(2)}" y="${height - 8}" text-anchor="middle" fill="${theme.axisSoft}" font-size="11">${year}</text>`).join('');
  const bars = years.map((year) => {
    const salary = salaryMap.get(year)?.salary || 0;
    if (!salary) return '';
    const xPos = x(year) - barWidth / 2;
    const yPos = y(salary);
    const h = Math.max(height - padding.bottom - yPos, 3);
    return `<rect x="${xPos.toFixed(2)}" y="${yPos.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${h.toFixed(2)}" rx="10" fill="rgba(77,183,255,0.42)"></rect>`;
  }).join('');
  const incomeSeries = data.incomePoints.filter((item) => years.includes(item.year));
  const linePoints = incomeSeries.map((item) => `${x(item.year).toFixed(2)},${y(item.totalIncome).toFixed(2)}`).join(' ');
  const areaPoints = [
    `${x(incomeSeries[0].year).toFixed(2)},${(height - padding.bottom).toFixed(2)}`,
    ...incomeSeries.map((item) => `${x(item.year).toFixed(2)},${y(item.totalIncome).toFixed(2)}`),
    `${x(incomeSeries[incomeSeries.length - 1].year).toFixed(2)},${(height - padding.bottom).toFixed(2)}`,
  ].join(' ');
  const markers = incomeSeries.map((item) => `<circle cx="${x(item.year).toFixed(2)}" cy="${y(item.totalIncome).toFixed(2)}" r="4.5" fill="#ffbf47"></circle>`).join('');
  const hotspots = years.map((year, index) => {
    const currentX = x(year);
    const prevX = index === 0 ? padding.left : x(years[index - 1]);
    const nextX = index === years.length - 1 ? width - padding.right : x(years[index + 1]);
    const startX = index === 0 ? padding.left : (prevX + currentX) / 2;
    const endX = index === years.length - 1 ? width - padding.right : (currentX + nextX) / 2;
    return `<rect x="${startX.toFixed(2)}" y="${padding.top}" width="${Math.max(endX - startX, 20).toFixed(2)}" height="${chartHeight.toFixed(2)}" fill="transparent" data-income-year="${year}"></rect>`;
  }).join('');
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  svg.innerHTML = `${grid}<polygon points="${areaPoints}" fill="rgba(255,191,71,0.10)"></polygon>${bars}<polyline points="${linePoints}" fill="none" stroke="#ffbf47" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"></polyline>${markers}${hotspots}${xLabels}`;
  shell.onclick = (event) => {
    const target = event.target.closest('[data-income-year]');
    if (!target) return closeTooltips();
    const year = Number(target.dataset.incomeYear);
    setTooltip(tooltip, target, shell, [
      String(year),
      { label: 'Ingresos totales', value: formatProfileCurrency(incomeMap.get(year)?.totalIncome) },
      { label: 'Salario Telefónica', value: formatProfileCurrency(salaryMap.get(year)?.salary) },
    ]);
  };
}

function renderSalaryChart(data) {
  const shell = document.getElementById('salaryChartShell');
  const svg = document.getElementById('salaryChart');
  const tooltip = document.getElementById('salaryTooltip');
  const years = data.salaryPoints.map((item) => item.year);
  if (!years.length) {
    svg.innerHTML = `<text x="50%" y="50%" text-anchor="middle" fill="${getChartTheme().empty}" font-size="16">Sin datos suficientes</text>`;
    return;
  }
  const theme = getChartTheme();
  const width = 960;
  const height = 336;
  const padding = { top: 18, right: 20, bottom: 34, left: 84 };
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;
  const xStep = years.length === 1 ? 0 : chartWidth / (years.length - 1);
  const maxValue = Math.max(...data.salaryPoints.map((item) => item.salary), 1);
  const domainMax = maxValue * 1.16;
  const y = (value) => padding.top + chartHeight - (value / domainMax) * chartHeight;
  const x = (year) => padding.left + (years.length === 1 ? chartWidth / 2 : years.indexOf(year) * xStep);
  const yTicks = buildTicks(domainMax, 4);
  const sampledYears = sampleProfileYears(years);
  const barWidth = Math.min(44, Math.max(chartWidth / Math.max(years.length * 1.9, 1), 20));
  const grid = yTicks.map((tick) => `
    <g>
      <line x1="${padding.left}" y1="${y(tick).toFixed(2)}" x2="${width - padding.right}" y2="${y(tick).toFixed(2)}" stroke="${theme.grid}" stroke-width="1" stroke-dasharray="4 6"></line>
      <text x="${padding.left - 12}" y="${(y(tick) + 4).toFixed(2)}" text-anchor="end" fill="${theme.axis}" font-size="11">${formatProfileAxisCurrency(tick)}</text>
    </g>
  `).join('');
  const xLabels = sampledYears.map((year) => `<text x="${x(year).toFixed(2)}" y="${height - 8}" text-anchor="middle" fill="${theme.axisSoft}" font-size="11">${year}</text>`).join('');
  const stacks = data.salaryPoints.map((point) => {
    const left = x(point.year) - barWidth / 2;
    const grossTop = y(point.grossSalary);
    const grossHeight = Math.max(height - padding.bottom - grossTop, 3);
    const bonusTop = y(point.grossSalary + point.bonus);
    const bonusHeight = point.bonus > 0 ? Math.max(y(point.grossSalary) - bonusTop, 3) : 0;
    const topTop = y(point.salary);
    const topHeight = point.topPerformer > 0 ? Math.max(y(point.grossSalary + point.bonus) - topTop, 3) : 0;
    return `<rect x="${left.toFixed(2)}" y="${grossTop.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${grossHeight.toFixed(2)}" rx="10" fill="#4db7ff"></rect>${point.bonus > 0 ? `<rect x="${left.toFixed(2)}" y="${bonusTop.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${bonusHeight.toFixed(2)}" rx="10" fill="#ffbf47"></rect>` : ''}${point.topPerformer > 0 ? `<rect x="${left.toFixed(2)}" y="${topTop.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${topHeight.toFixed(2)}" rx="10" fill="#b38cff"></rect>` : ''}`;
  }).join('');
  const hotspots = data.salaryPoints.map((point, index) => {
    const currentX = x(point.year);
    const prevX = index === 0 ? padding.left : x(years[index - 1]);
    const nextX = index === years.length - 1 ? width - padding.right : x(years[index + 1]);
    const startX = index === 0 ? padding.left : (prevX + currentX) / 2;
    const endX = index === years.length - 1 ? width - padding.right : (currentX + nextX) / 2;
    return `<rect x="${startX.toFixed(2)}" y="${padding.top}" width="${Math.max(endX - startX, 20).toFixed(2)}" height="${chartHeight.toFixed(2)}" fill="transparent" data-salary-year="${point.year}"></rect>`;
  }).join('');
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  svg.innerHTML = `${grid}${stacks}${hotspots}${xLabels}`;
  const pointMap = new Map(data.salaryPoints.map((item) => [item.year, item]));
  shell.onclick = (event) => {
    const target = event.target.closest('[data-salary-year]');
    if (!target) return closeTooltips();
    const point = pointMap.get(Number(target.dataset.salaryYear));
    if (!point) return closeTooltips();
    const lines = [
      String(point.year),
      { label: 'Salario bruto', value: formatProfileCurrency(point.grossSalary) },
      { label: 'Bonus', value: formatProfileCurrency(point.bonus) },
    ];
    if (point.topPerformer > 0) lines.push({ label: 'Top performer', value: formatProfileCurrency(point.topPerformer) });
    lines.push({ label: 'Total', value: formatProfileCurrency(point.salary) });
    setTooltip(tooltip, target, shell, lines);
  };
}

function buildSummaryRows(data) {
  const incomeByYear = new Map(data.incomePoints.map((item) => [item.year, item]));
  const salaryByYear = new Map(data.salaryPoints.map((item) => [item.year, item]));
  const years = Array.from(new Set([...incomeByYear.keys(), ...salaryByYear.keys()])).sort((a, b) => b - a);
  return years.map((year) => {
    const income = incomeByYear.get(year);
    const salary = salaryByYear.get(year);
    return `
      <tr>
        <td class="emph">${year}</td>
        <td>${formatProfileCurrency(income?.totalIncome)}</td>
        <td>${formatProfileCurrency(salary?.salary)}</td>
        <td>${formatProfileCurrency(salary?.grossSalary)}</td>
        <td>${formatProfileCurrency(salary?.bonus)}</td>
        <td>${salary?.topPerformer > 0 ? formatProfileCurrency(salary.topPerformer) : '-'}</td>
      </tr>
    `;
  }).join('');
}

function renderProfilePage(profile) {
  const root = document.getElementById('profileContent');
  const data = getVisibleProfileData(profile);
  const avatar = document.getElementById('profileAvatar');
  const nameNode = document.getElementById('profileName');
  const subtitleNode = document.getElementById('profileSubtitle');
  if (nameNode) nameNode.textContent = data.fullName;
  if (subtitleNode) subtitleNode.textContent = 'Ingresos y evolución salarial';
  if (avatar) {
    avatar.innerHTML = `<img src="${PROFILE_PHOTO_SRC}" alt="Foto de Denis Martín Barroso"><span>DMB</span>`;
    const img = avatar.querySelector('img');
    if (img) {
      img.onerror = () => avatar.classList.remove('has-image');
      img.onload = () => avatar.classList.add('has-image');
    }
  }
  if ((!data.incomePoints.length && !data.salaryPoints.length) || data.error) {
    root.innerHTML = `<div class="status-empty">${data.error || 'Todavía no hay datos de perfil disponibles.'}</div>`;
    return;
  }
  root.innerHTML = `
    <div class="profile-grid">
      <section class="profile-panel">
        <h3>Evolución de ingresos totales anuales</h3>
        <p>Ingresos totales frente a salario Telefónica.</p>
        <div class="chart-shell" id="incomeChartShell">
          <svg id="incomeChart" aria-label="Evolución de ingresos"></svg>
          <div class="chart-tooltip" id="incomeTooltip"></div>
        </div>
        <div class="legend-row">
          <span class="legend-item"><span class="swatch" style="background:#ffbf47"></span>Ingresos totales</span>
          <span class="legend-item"><span class="swatch" style="background:rgba(77,183,255,0.7)"></span>Total salario Telefónica</span>
        </div>
      </section>
      <section class="profile-panel">
        <h3>Evolución salarial en Telefónica</h3>
        <p>Salario bruto, bonus y top performer.</p>
        <div class="chart-shell" id="salaryChartShell">
          <svg id="salaryChart" aria-label="Evolución salarial"></svg>
          <div class="chart-tooltip" id="salaryTooltip"></div>
        </div>
        <div class="legend-row">
          <span class="legend-item"><span class="swatch" style="background:#4db7ff"></span>Salario bruto</span>
          <span class="legend-item"><span class="swatch" style="background:#ffbf47"></span>Bonus</span>
          <span class="legend-item"><span class="swatch" style="background:#b38cff"></span>Top performer</span>
        </div>
      </section>
    </div>
    <section class="profile-panel">
      <h3>Resumen anual</h3>
      <p>Ingresos y desglose salarial por año.</p>
      <div class="summary-shell">
        <table class="summary-table">
          <thead>
            <tr>
              <th>Año</th>
              <th>Ingresos</th>
              <th>Total salario</th>
              <th>Bruto</th>
              <th>Bonus</th>
              <th>Top performer</th>
            </tr>
          </thead>
          <tbody>${buildSummaryRows(data)}</tbody>
        </table>
      </div>
    </section>
  `;
  renderIncomeChart(data);
  renderSalaryChart(data);
}

async function loadProfile() {
  const status = document.getElementById('statusMessage');
  if (status) status.textContent = 'Cargando datos de perfil...';
  try {
    const response = await fetch(`/api/portfolio?ts=${Date.now()}`, {
      cache: 'no-store',
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const payload = await response.json();
    renderProfilePage(payload.profile || {});
    if (status) status.textContent = `Datos cargados · ${payload.generatedAt}`;
  } catch (error) {
    console.error(error);
    const root = document.getElementById('profileContent');
    root.innerHTML = '<div class="status-empty">No se pudo leer la información de perfil desde Google Sheets.</div>';
    if (status) status.textContent = 'No se pudieron cargar los datos.';
  }
}

document.getElementById('themeToggleButton')?.addEventListener('click', () => {
  applyTheme(document.documentElement.dataset.theme === 'light' ? 'dark' : 'light');
  loadProfile();
});

document.getElementById('privacyToggleButton')?.addEventListener('click', () => {
  applyPrivacyPreference(!state.hideSensitiveValues);
  loadProfile();
});

document.addEventListener('click', (event) => {
  if (!event.target.closest('[data-income-year]') && !event.target.closest('[data-salary-year]')) {
    closeTooltips();
  }
});

document.addEventListener('DOMContentLoaded', () => {
  try {
    applyTheme(localStorage.getItem('investment-theme') || 'dark');
  } catch {
    applyTheme('dark');
  }
  try {
    applyPrivacyPreference(localStorage.getItem('investment-hide-sensitive') === 'true');
  } catch {
    applyPrivacyPreference(false);
  }
  loadProfile();
});
