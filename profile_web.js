(function () {
  const PROFILE_PHOTO_SRC = 'assets/profile-photo.png';

  function getProfilePayload() {
    return (typeof rawData !== 'undefined' && rawData && rawData.profile) ? rawData.profile : {};
  }

  function getVisibleProfileData() {
    const profile = getProfilePayload();
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
    const visibleMaxYear = maxIncomeYear || salaryPoints.reduce((max, item) => Math.max(max, item.year), 0);

    return {
      fullName: profile.fullName || 'Denis Martín Barroso',
      error: profile.error || null,
      incomePoints: incomePoints.filter((item) => item.year <= visibleMaxYear),
      salaryPoints: salaryPoints.filter((item) => item.year <= visibleMaxYear),
    };
  }

  function sampleProfileYears(years) {
    if (years.length <= 4) return years;
    const maxLabels = years.length > 10 ? 5 : years.length > 7 ? 4 : 5;
    const step = Math.max(Math.ceil(years.length / maxLabels), 1);
    return years.filter((year, index) => index === 0 || index === years.length - 1 || index % step === 0);
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

  function buildTicks(maxValue, count) {
    const safeMax = Math.max(maxValue, 1);
    return Array.from({ length: count + 1 }, (_, index) => (safeMax / count) * index);
  }

  function getProfilePhotoMarkup(sizeClass) {
    return `
      <div class="${sizeClass} has-image">
        <img src="${PROFILE_PHOTO_SRC}" alt="Foto de Denis Martín Barroso">
        <span>DMB</span>
      </div>
    `;
  }

  function closeProfileTooltips() {
    document.querySelectorAll('#profileIncomeTooltip, #profileSalaryTooltip').forEach((node) => {
      if (node) {
        node.classList.remove('is-visible');
      }
    });
  }

  function openProfileModal() {
    renderProfileModal();
    const modal = document.getElementById('profileModal');
    modal.classList.add('is-open');
    modal.setAttribute('aria-hidden', 'false');
  }

  function closeProfileModal() {
    closeProfileTooltips();
    const modal = document.getElementById('profileModal');
    modal.classList.remove('is-open');
    modal.setAttribute('aria-hidden', 'true');
  }

  function setProfileTooltip(tooltip, anchor, shell, lines) {
    if (!tooltip || !anchor || !shell) return;
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

  function renderProfileIncomeChart(data) {
    const shell = document.getElementById('profileIncomeChartShell');
    const svg = document.getElementById('profileIncomeChart');
    const tooltip = document.getElementById('profileIncomeTooltip');
    if (!shell || !svg || !tooltip) return;

    const incomeMap = new Map(data.incomePoints.map((item) => [item.year, item]));
    const salaryMap = new Map(data.salaryPoints.map((item) => [item.year, item]));
    const years = Array.from(new Set([...incomeMap.keys(), ...salaryMap.keys()])).sort((a, b) => a - b);
    if (!years.length) {
      svg.innerHTML = `<text x="50%" y="50%" text-anchor="middle" fill="${getChartTheme().empty}" font-size="16">Sin datos suficientes</text>`;
      return;
    }

    const theme = getChartTheme();
    const width = 940;
    const height = 328;
    const padding = { top: 18, right: 20, bottom: 34, left: 84 };
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;
    const xStep = years.length === 1 ? 0 : chartWidth / (years.length - 1);
    const maxValue = Math.max(
      ...data.incomePoints.map((item) => item.totalIncome),
      ...data.salaryPoints.map((item) => item.salary),
      1,
    );
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

    const xLabels = sampledYears.map((year) => `
      <text x="${x(year).toFixed(2)}" y="${height - 8}" text-anchor="middle" fill="${theme.axisSoft}" font-size="11">${year}</text>
    `).join('');

    const bars = years.map((year) => {
      const salary = salaryMap.get(year)?.salary || 0;
      if (!salary) return '';
      const xPos = x(year) - barWidth / 2;
      const yPos = y(salary);
      const h = Math.max(height - padding.bottom - yPos, 3);
      return `
        <rect x="${xPos.toFixed(2)}" y="${yPos.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${h.toFixed(2)}" rx="10" fill="rgba(77,183,255,0.42)"></rect>
      `;
    }).join('');

    const incomeSeries = data.incomePoints.filter((item) => years.includes(item.year));
    const linePoints = incomeSeries.map((item) => `${x(item.year).toFixed(2)},${y(item.totalIncome).toFixed(2)}`).join(' ');
    const areaPoints = [
      `${x(incomeSeries[0].year).toFixed(2)},${(height - padding.bottom).toFixed(2)}`,
      ...incomeSeries.map((item) => `${x(item.year).toFixed(2)},${y(item.totalIncome).toFixed(2)}`),
      `${x(incomeSeries[incomeSeries.length - 1].year).toFixed(2)},${(height - padding.bottom).toFixed(2)}`,
    ].join(' ');

    const markers = incomeSeries.map((item) => `
      <circle cx="${x(item.year).toFixed(2)}" cy="${y(item.totalIncome).toFixed(2)}" r="4.5" fill="#ffbf47"></circle>
    `).join('');

    const hotspots = years.map((year, index) => {
      const currentX = x(year);
      const prevX = index === 0 ? padding.left : x(years[index - 1]);
      const nextX = index === years.length - 1 ? width - padding.right : x(years[index + 1]);
      const startX = index === 0 ? padding.left : (prevX + currentX) / 2;
      const endX = index === years.length - 1 ? width - padding.right : (currentX + nextX) / 2;
      return `
        <rect x="${startX.toFixed(2)}" y="${padding.top}" width="${Math.max(endX - startX, 20).toFixed(2)}" height="${chartHeight.toFixed(2)}" fill="transparent" data-profile-income-year="${year}"></rect>
      `;
    }).join('');

    svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
    svg.innerHTML = `
      ${grid}
      <polygon points="${areaPoints}" fill="rgba(255,191,71,0.10)"></polygon>
      ${bars}
      <polyline points="${linePoints}" fill="none" stroke="#ffbf47" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"></polyline>
      ${markers}
      ${hotspots}
      ${xLabels}
    `;

    shell.onclick = (event) => {
      const target = event.target.closest('[data-profile-income-year]');
      if (!target) {
        closeProfileTooltips();
        return;
      }
      const year = Number(target.dataset.profileIncomeYear);
      const income = incomeMap.get(year)?.totalIncome;
      const salary = salaryMap.get(year)?.salary;
      setProfileTooltip(tooltip, target, shell, [
        String(year),
        { label: 'Ingresos totales', value: formatProfileCurrency(income) },
        { label: 'Salario Telefónica', value: formatProfileCurrency(salary) },
      ]);
    };
  }

  function renderProfileSalaryChart(data) {
    const shell = document.getElementById('profileSalaryChartShell');
    const svg = document.getElementById('profileSalaryChart');
    const tooltip = document.getElementById('profileSalaryTooltip');
    if (!shell || !svg || !tooltip) return;

    const years = data.salaryPoints.map((item) => item.year);
    if (!years.length) {
      svg.innerHTML = `<text x="50%" y="50%" text-anchor="middle" fill="${getChartTheme().empty}" font-size="16">Sin datos suficientes</text>`;
      return;
    }

    const theme = getChartTheme();
    const width = 940;
    const height = 328;
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

    const xLabels = sampledYears.map((year) => `
      <text x="${x(year).toFixed(2)}" y="${height - 8}" text-anchor="middle" fill="${theme.axisSoft}" font-size="11">${year}</text>
    `).join('');

    const stacks = data.salaryPoints.map((point) => {
      const left = x(point.year) - barWidth / 2;
      const grossTop = y(point.grossSalary);
      const grossHeight = Math.max(height - padding.bottom - grossTop, 3);
      const bonusTop = y(point.grossSalary + point.bonus);
      const bonusHeight = point.bonus > 0 ? Math.max(y(point.grossSalary) - bonusTop, 3) : 0;
      const topTop = y(point.salary);
      const topHeight = point.topPerformer > 0 ? Math.max(y(point.grossSalary + point.bonus) - topTop, 3) : 0;
      return `
        <rect x="${left.toFixed(2)}" y="${grossTop.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${grossHeight.toFixed(2)}" rx="10" fill="#4db7ff"></rect>
        ${point.bonus > 0 ? `<rect x="${left.toFixed(2)}" y="${bonusTop.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${bonusHeight.toFixed(2)}" rx="10" fill="#ffbf47"></rect>` : ''}
        ${point.topPerformer > 0 ? `<rect x="${left.toFixed(2)}" y="${topTop.toFixed(2)}" width="${barWidth.toFixed(2)}" height="${topHeight.toFixed(2)}" rx="10" fill="#b38cff"></rect>` : ''}
      `;
    }).join('');

    const hotspots = data.salaryPoints.map((point, index) => {
      const currentX = x(point.year);
      const prevX = index === 0 ? padding.left : x(years[index - 1]);
      const nextX = index === years.length - 1 ? width - padding.right : x(years[index + 1]);
      const startX = index === 0 ? padding.left : (prevX + currentX) / 2;
      const endX = index === years.length - 1 ? width - padding.right : (currentX + nextX) / 2;
      return `
        <rect x="${startX.toFixed(2)}" y="${padding.top}" width="${Math.max(endX - startX, 20).toFixed(2)}" height="${chartHeight.toFixed(2)}" fill="transparent" data-profile-salary-year="${point.year}"></rect>
      `;
    }).join('');

    svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
    svg.innerHTML = `
      ${grid}
      ${stacks}
      ${hotspots}
      ${xLabels}
    `;

    const pointMap = new Map(data.salaryPoints.map((item) => [item.year, item]));
    shell.onclick = (event) => {
      const target = event.target.closest('[data-profile-salary-year]');
      if (!target) {
        closeProfileTooltips();
        return;
      }
      const year = Number(target.dataset.profileSalaryYear);
      const point = pointMap.get(year);
      if (!point) {
        closeProfileTooltips();
        return;
      }
      const lines = [
        String(year),
        { label: 'Salario bruto', value: formatProfileCurrency(point.grossSalary) },
        { label: 'Bonus', value: formatProfileCurrency(point.bonus) },
      ];
      if (point.topPerformer > 0) {
        lines.push({ label: 'Top performer', value: formatProfileCurrency(point.topPerformer) });
      }
      lines.push({ label: 'Total', value: formatProfileCurrency(point.salary) });
      setProfileTooltip(tooltip, target, shell, lines);
    };
  }

  function buildProfileSummaryRows(data) {
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

  function renderProfileModal() {
    const body = document.getElementById('profileModalBody');
    if (!body) return;

    const data = getVisibleProfileData();
    if ((!data.incomePoints.length && !data.salaryPoints.length) || data.error) {
      body.innerHTML = `
        <div class="profile-body">
          <div class="profile-hero">
            ${getProfilePhotoMarkup('profile-avatar-large')}
            <h3>${data.fullName}</h3>
            <p>Mi Perfil</p>
          </div>
          <div class="profile-empty">${data.error || 'Todavía no hay datos de perfil disponibles.'}</div>
        </div>
      `;
      return;
    }

    body.innerHTML = `
      <div class="profile-body">
        <div class="profile-hero">
          ${getProfilePhotoMarkup('profile-avatar-large')}
          <h3>${data.fullName}</h3>
          <p>Ingresos y evolución salarial</p>
        </div>
        <div class="profile-grid">
          <section class="profile-panel">
            <h3>Evolución de ingresos totales anuales</h3>
            <p>Ingresos totales frente a salario Telefónica.</p>
            <div class="profile-chart-shell" id="profileIncomeChartShell">
              <svg id="profileIncomeChart" aria-label="Evolución de ingresos"></svg>
              <div class="chart-tooltip profile-chart-tooltip" id="profileIncomeTooltip"></div>
            </div>
            <div class="profile-legend">
              <span class="profile-legend-item"><span class="swatch" style="background:#ffbf47"></span>Ingresos totales</span>
              <span class="profile-legend-item"><span class="swatch" style="background:rgba(77,183,255,0.7)"></span>Total salario Telefónica</span>
            </div>
          </section>
          <section class="profile-panel">
            <h3>Evolución salarial en Telefónica</h3>
            <p>Salario bruto, bonus y top performer.</p>
            <div class="profile-chart-shell" id="profileSalaryChartShell">
              <svg id="profileSalaryChart" aria-label="Evolución salarial"></svg>
              <div class="chart-tooltip profile-chart-tooltip" id="profileSalaryTooltip"></div>
            </div>
            <div class="profile-legend">
              <span class="profile-legend-item"><span class="swatch" style="background:#4db7ff"></span>Salario bruto</span>
              <span class="profile-legend-item"><span class="swatch" style="background:#ffbf47"></span>Bonus</span>
              <span class="profile-legend-item"><span class="swatch" style="background:#b38cff"></span>Top performer</span>
            </div>
          </section>
        </div>
        <section class="profile-panel">
          <h3>Resumen anual</h3>
          <p>Ingresos y desglose salarial por año.</p>
          <div class="profile-summary-shell">
            <table class="profile-summary-table">
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
              <tbody>
                ${buildProfileSummaryRows(data)}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    `;

    document.querySelectorAll('.profile-avatar-thumb, .profile-avatar-large').forEach((node) => {
      const img = node.querySelector('img');
      if (!img) return;
      img.onerror = () => node.classList.remove('has-image');
      img.onload = () => node.classList.add('has-image');
    });

    renderProfileIncomeChart(data);
    renderProfileSalaryChart(data);
  }

  function attachProfileModal() {
    const openButton = document.getElementById('openProfileButton');
    const closeButton = document.getElementById('closeProfileButton');
    const modal = document.getElementById('profileModal');
    if (!openButton || !closeButton || !modal) return;

    openButton.addEventListener('click', openProfileModal);
    closeButton.addEventListener('click', closeProfileModal);
    modal.addEventListener('click', (event) => {
      if (event.target.id === 'profileModal') {
        closeProfileModal();
      } else if (!event.target.closest('[data-profile-income-year]') && !event.target.closest('[data-profile-salary-year]')) {
        closeProfileTooltips();
      }
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        closeProfileTooltips();
        closeProfileModal();
      }
    });
  }

  function patchRenderAll() {
    if (typeof renderAll !== 'function') return;
    const originalRenderAll = renderAll;
    renderAll = function (...args) {
      const result = originalRenderAll.apply(this, args);
      renderProfileModal();
      return result;
    };
  }

  function initProfileWeb() {
    patchRenderAll();
    attachProfileModal();
    renderProfileModal();
  }

  initProfileWeb();
})();
