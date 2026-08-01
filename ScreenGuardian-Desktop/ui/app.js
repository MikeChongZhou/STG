/**
 * ScreenGuardian Desktop - UI Application Logic
 * Handles page navigation, data display, and user interactions
 */

// ============================================================
// Navigation
// ============================================================

const navItems = document.querySelectorAll('.nav-item');
const pages = document.querySelectorAll('.page');
const menuCards = document.querySelectorAll('.menu-card');

function navigateTo(pageName) {
  navItems.forEach(item => item.classList.toggle('active', item.dataset.page === pageName));
  pages.forEach(page => page.classList.toggle('active', page.id === `page-${pageName}`));
  // Load page data
  if (pageName === 'report') loadReport();
  if (pageName === 'plan') loadPlan();
  if (pageName === 'tracking') loadTracking();
  if (pageName === 'settings') loadSettings();
}

navItems.forEach(item => item.addEventListener('click', () => navigateTo(item.dataset.page)));
menuCards.forEach(card => card.addEventListener('click', () => navigateTo(card.dataset.nav)));

// ============================================================
// Home Page - Live Updates
// ============================================================

function formatDuration(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0 && m > 0) return `${h}小时${m}分钟`;
  if (h > 0) return `${h}小时`;
  if (m > 0) return `${m}分钟`;
  return '不到1分钟';
}

async function updateHomeStats() {
  try {
    const elapsed = await window.sgAPI.getCurrentElapsed();
    const total = await window.sgAPI.getTodayTotal();
    document.getElementById('currentElapsed').textContent = formatDuration(elapsed);
    document.getElementById('todayTotal').textContent = formatDuration(total);
  } catch (e) {
    console.error('Failed to update stats:', e);
  }
}

setInterval(updateHomeStats, 1000);
updateHomeStats();

// Load version for about page
(async () => {
  try {
    const version = await window.sgAPI.getVersion();
    document.getElementById('aboutVersion').textContent = `Version: V${version}`;
  } catch {}
})();

// Minimize to tray
document.getElementById('btnMinimize').addEventListener('click', () => {
  window.sgAPI.minimizeToTray();
});

// ============================================================
// Report Page
// ============================================================

let reportMode = 'daily';

document.querySelectorAll('.seg-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.seg-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    reportMode = btn.dataset.mode;
    document.getElementById('reportDate').style.display = reportMode === 'daily' ? '' : 'none';
    document.getElementById('reportStartDate').style.display = reportMode === 'range' ? '' : 'none';
    document.getElementById('reportEndDate').style.display = reportMode === 'range' ? '' : 'none';
  });
});

// Set default dates
const today = new Date();
document.getElementById('reportDate').value = today.toISOString().split('T')[0];
document.getElementById('reportStartDate').value = new Date(today - 6 * 86400000).toISOString().split('T')[0];
document.getElementById('reportEndDate').value = today.toISOString().split('T')[0];

document.getElementById('btnGenerateReport').addEventListener('click', loadReport);

async function loadReport() {
  const content = document.getElementById('reportContent');
  content.innerHTML = '<div class="loading">加载中...</div>';

  try {
    let sessions, summaries;
    if (reportMode === 'daily') {
      const date = document.getElementById('reportDate').value;
      sessions = await window.sgAPI.querySessions({ startDate: date, endDate: date });
      summaries = await window.sgAPI.querySummaries({ startDate: date, endDate: date });
    } else {
      const startDate = document.getElementById('reportStartDate').value;
      const endDate = document.getElementById('reportEndDate').value;
      sessions = await window.sgAPI.querySessions({ startDate, endDate });
      summaries = await window.sgAPI.querySummaries({ startDate, endDate });
    }

    if (summaries.length === 0 && sessions.length === 0) {
      content.innerHTML = '<div class="empty-state"><span class="emoji">📊</span><p>暂无数据</p></div>';
      return;
    }

    const totalSeconds = summaries.reduce((sum, s) => sum + s.totalSeconds, 0);
    const sessionCount = summaries.reduce((sum, s) => sum + s.sessionCount, 0);
    const dayCount = summaries.length || 1;
    const avgSeconds = Math.floor(totalSeconds / dayCount);

    let html = `
      <div class="summary-card">
        <div class="summary-date">${reportMode === 'daily' ? document.getElementById('reportDate').value : `${document.getElementById('reportStartDate').value} ~ ${document.getElementById('reportEndDate').value}`}</div>
        <div class="summary-total">${formatDuration(totalSeconds)}</div>
        <div class="summary-label">总用时</div>
        <div class="summary-badges">
          <div class="badge">
            <span class="badge-emoji">📱</span>
            <span class="badge-value">${sessionCount}</span>
            <span class="badge-label">次使用</span>
          </div>
          ${reportMode === 'range' ? `
          <div class="badge">
            <span class="badge-emoji">📅</span>
            <span class="badge-value">${dayCount}</span>
            <span class="badge-label">天</span>
          </div>
          <div class="badge">
            <span class="badge-emoji">📊</span>
            <span class="badge-value">${formatDuration(avgSeconds)}</span>
            <span class="badge-label">日均</span>
          </div>` : ''}
        </div>
      </div>
    `;

    // Daily breakdown for range mode
    if (reportMode === 'range' && summaries.length > 1) {
      const maxSeconds = Math.max(...summaries.map(s => s.totalSeconds));
      html += '<div class="daily-breakdown"><h3>每日明细</h3>';
      for (const s of summaries.reverse().slice(0, 14)) {
        const ratio = maxSeconds > 0 ? s.totalSeconds / maxSeconds : 0;
        const color = s.totalSeconds > 7200 ? 'var(--red)' : (s.totalSeconds > 3600 ? 'var(--orange)' : 'var(--primary-light)');
        html += `
          <div class="daily-row">
            <span class="daily-label">${s.date.substring(5)}</span>
            <div class="daily-bar-bg">
              <div class="daily-bar" style="width:${Math.min(ratio * 100, 100)}%;background:${color}"></div>
            </div>
            <span class="daily-value">${formatDuration(s.totalSeconds)}</span>
          </div>`;
      }
      html += '</div>';
    }

    // Session list
    if (sessions.length > 0) {
      html += '<div class="session-list"><h3>时段明细</h3>';
      for (const s of sessions.reverse().slice(0, 50)) {
        const startTime = new Date(s.startTime).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
        const endTime = s.endTime ? new Date(s.endTime).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' }) : '...';
        const duration = formatDuration(s.durationSeconds || 0);
        const isLong = (s.durationSeconds || 0) > 3600;
        html += `
          <div class="session-item">
            <div class="session-bar ${isLong ? 'long' : ''}"></div>
            <div class="session-info">
              <div class="session-time">${startTime} - ${endTime}</div>
              <div class="session-detail">${duration}</div>
            </div>
            <div class="session-device">${s.deviceName}</div>
          </div>`;
      }
      html += '</div>';
    }

    content.innerHTML = html;
  } catch (e) {
    content.innerHTML = `<div class="error">加载失败: ${e.message}</div>`;
  }
}

// ============================================================
// Weekly Plan Page
// ============================================================

async function loadPlan() {
  const today = new Date().toISOString().split('T')[0];
  const monday = getMonday(today);
  const sunday = addDays(monday, 6);

  document.getElementById('planWeekRange').textContent = `${monday} ~ ${sunday}`;

  try {
    const plan = await window.sgAPI.getWeeklyPlan(monday);
    const summaries = await window.sgAPI.querySummaries({ startDate: monday, endDate: sunday });

    const slider = document.getElementById('planSlider');
    const sliderValue = document.getElementById('planSliderValue');
    const planValue = document.getElementById('planValue');
    const planSource = document.getElementById('planSource');

    if (plan) {
      slider.value = plan.plannedDailyMinutes;
      planValue.textContent = formatDuration(plan.plannedDailyMinutes * 60);
      planSource.textContent = plan.source === 'user_input' ? '手动设定' : '根据上周数据自动填入';
    } else {
      slider.value = 480;
      planValue.textContent = '--';
      planSource.textContent = '尚未设定本周计划';
    }

    sliderValue.textContent = formatDuration(slider.value * 60);

    slider.oninput = () => {
      sliderValue.textContent = formatDuration(slider.value * 60);
      planValue.textContent = formatDuration(slider.value * 60);
    };

    // Presets
    document.querySelectorAll('.preset-btn').forEach(btn => {
      btn.classList.toggle('active', parseInt(btn.dataset.minutes) === parseInt(slider.value));
      btn.onclick = () => {
        slider.value = btn.dataset.minutes;
        sliderValue.textContent = formatDuration(slider.value * 60);
        planValue.textContent = formatDuration(slider.value * 60);
        document.querySelectorAll('.preset-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
      };
    });

    // Save
    document.getElementById('btnSavePlan').onclick = async () => {
      const minutes = parseInt(slider.value);
      if (minutes < 30 || minutes > 720) {
        alert('计划用时需在 30-720 分钟之间');
        return;
      }
      await window.sgAPI.saveWeeklyPlan({
        weekStart: monday,
        plannedDailyMinutes: minutes,
        source: plan ? 'user_input' : 'auto_from_last_week',
        createdAt: (plan?.createdAt || new Date().toISOString()),
      });
      alert('计划已保存 ✓');
      loadPlan();
    };

    // Progress
    if (plan && summaries.length > 0) {
      const plannedSeconds = plan.plannedDailyMinutes * 60;
      const totalWeek = summaries.reduce((sum, s) => sum + s.totalSeconds, 0);
      const avg = summaries.length > 0 ? Math.floor(totalWeek / summaries.length) : 0;
      const daysOver = summaries.filter(s => s.totalSeconds > plannedSeconds).length;

      const progressCard = document.getElementById('planProgressCard');
      progressCard.style.display = '';
      const progressContent = document.getElementById('planProgressContent');
      progressContent.innerHTML = `
        <div style="display:flex;gap:24px;justify-content:center;margin-bottom:20px">
          <div style="text-align:center">
            <div style="font-size:20px">📅</div>
            <div style="font-weight:bold;font-size:15px;color:var(--primary)">${formatDuration(totalWeek)}</div>
            <div style="font-size:11px;color:var(--text-muted)">本周累计</div>
          </div>
          <div style="text-align:center">
            <div style="font-size:20px">📊</div>
            <div style="font-weight:bold;font-size:15px;color:var(--primary)">${formatDuration(avg)}</div>
            <div style="font-size:11px;color:var(--text-muted)">日均</div>
          </div>
          <div style="text-align:center">
            <div style="font-size:20px">⚠️</div>
            <div style="font-weight:bold;font-size:15px;color:var(--primary)">${daysOver} / ${summaries.length}</div>
            <div style="font-size:11px;color:var(--text-muted)">超计划天数</div>
          </div>
        </div>
      `;
    }
  } catch (e) {
    console.error('Failed to load plan:', e);
  }
}

// ============================================================
// Tracking Page
// ============================================================

async function loadTracking() {
  const content = document.getElementById('trackingContent');
  content.innerHTML = '<div class="loading">正在获取数据...</div>';

  try {
    const data = await window.sgAPI.fetchRanking();
    if (!data || !data.data || data.data.length === 0) {
      content.innerHTML = '<div class="empty-state"><span class="emoji">📡</span><p>暂无数据</p></div>';
      return;
    }

    const totalRevenue = data.data.reduce((sum, e) => sum + (e.weeklyRevenue || 0), 0);
    const totalPrompt = data.data.reduce((sum, e) => sum + (e.promptTokens || 0), 0);
    const totalCompletion = data.data.reduce((sum, e) => sum + (e.completionTokens || 0), 0);

    let html = `
      <div class="tracking-summary">
        <div class="tracking-summary-card">
          <span class="emoji">💰</span>
          <span class="value">$${totalRevenue.toLocaleString()}</span>
          <span class="label">Revenue</span>
        </div>
        <div class="tracking-summary-card">
          <span class="emoji">📥</span>
          <span class="value">${formatTokens(totalPrompt)}</span>
          <span class="label">Prompt</span>
        </div>
        <div class="tracking-summary-card">
          <span class="emoji">📤</span>
          <span class="value">${formatTokens(totalCompletion)}</span>
          <span class="label">Output</span>
        </div>
      </div>
      <p style="font-size:12px;color:var(--text-muted);margin-bottom:8px">
        Source: OpenRouter | ${data.weekStart} ~ ${data.weekEnd}
      </p>
      <table class="ranking-table">
        <thead>
          <tr>
            <th>#</th>
            <th>模型</th>
            <th>提供商</th>
            <th class="num">Prompt Tokens</th>
            <th class="num">Output Tokens</th>
            <th class="num">Weekly Revenue</th>
          </tr>
        </thead>
        <tbody>
    `;

    for (const e of data.data) {
      html += `
        <tr>
          <td>${e.rank}</td>
          <td><strong>${e.modelName}</strong></td>
          <td>${e.provider}</td>
          <td class="num">${formatTokens(e.promptTokens)}</td>
          <td class="num">${formatTokens(e.completionTokens)}</td>
          <td class="num revenue">$${(e.weeklyRevenue || 0).toLocaleString()}</td>
        </tr>`;
    }

    html += '</tbody></table>';
    content.innerHTML = html;
    document.getElementById('trackingSource').textContent = `Source: OpenRouter | ${data.weekStart} ~ ${data.weekEnd}`;
  } catch (e) {
    content.innerHTML = `<div class="error">获取失败: ${e.message}</div>`;
  }
}

document.getElementById('btnRefreshRanking').addEventListener('click', loadTracking);

function formatTokens(n) {
  if (n == null) return '-';
  if (n >= 1e9) return `${(n / 1e9).toFixed(1)}B`;
  if (n >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (n >= 1e3) return `${(n / 1e3).toFixed(1)}K`;
  return String(n);
}

// ============================================================
// Settings Page
// ============================================================

async function loadSettings() {
  try {
    const config = await window.sgAPI.getConfig();
    const deviceInfo = await window.sgAPI.getDeviceInfo();

    document.getElementById('settingLanguage').value = config.language;
    document.getElementById('settingDeviceName').value = config.deviceName || '';
    document.getElementById('settingEyeRest').checked = config.eyeRestEnabled;
    document.getElementById('settingPosture').checked = config.postureEnabled;
    // Posture interval is now derived: 2× eye rest (40 min)
    document.getElementById('settingMeetingMode').checked = config.meetingMode;
    document.getElementById('settingOvertime').checked = config.overtimeEnabled;
    // P2P Sync status
    const syncStatus = await window.sgAPI.getSyncStatus();
    const statusText = document.getElementById('syncStatusText');
    const syncInfo = document.getElementById('syncInfo');
    statusText.textContent = syncStatus.running ? `运行中 (端口 ${syncStatus.port})` : '未启动';
    statusText.style.color = syncStatus.running ? 'var(--green)' : 'var(--text-muted)';
    if (syncStatus.paired) syncInfo.textContent = '🔒 已加密';

    // Show discovered devices
    if (syncStatus.devices && syncStatus.devices.length > 0) {
      const devDiv = document.getElementById('discoveredDevices');
      devDiv.innerHTML = '<h4 style="margin-bottom:8px">发现的设备</h4>' +
        syncStatus.devices.map(d => `<div style="padding:6px 0;border-bottom:1px solid #f0f0f0;font-size:13px">
          ${d.approved ? '✅' : '⏳'} ${d.deviceName} (${d.platform}) ${d.paired ? '🔒' : ''}
          <span style="color:var(--text-muted);font-size:11px">${d.ip}:${d.port}</span>
        </div>`).join('');
    }

    // Posture interval is now derived (no slider needed)
  } catch (e) {
    console.error('Failed to load settings:', e);
  }
}

document.getElementById('btnSaveSettings').addEventListener('click', async () => {
  try {
    const patch = {
      language: document.getElementById('settingLanguage').value,
      deviceName: document.getElementById('settingDeviceName').value || null,
      eyeRestEnabled: document.getElementById('settingEyeRest').checked,
      postureEnabled: document.getElementById('settingPosture').checked,
      postureIntervalMinutes: 40, // derived: 2× eye rest
      meetingMode: document.getElementById('settingMeetingMode').checked,
      overtimeEnabled: document.getElementById('settingOvertime').checked,
      syncFolderPath: document.getElementById('settingSyncPath').value || null,
    };

    await window.sgAPI.updateConfig(patch);

    // Handle P2P pairing code
    const pairingCode = document.getElementById('settingPairingCode').value;
    if (pairingCode && !syncStatus?.running) {
      await window.sgAPI.startP2P(pairingCode);
    }

    alert('设置已保存 ✓');
  } catch (e) {
    alert(`保存失败: ${e.message}`);
  }
});

document.getElementById('btnStartP2P').addEventListener('click', async () => {
  const code = document.getElementById('settingPairingCode').value;
  await window.sgAPI.startP2P(code || undefined);
  loadSettings();
});

document.getElementById('btnTriggerSync').addEventListener('click', async () => {
  const result = await window.sgAPI.triggerSync();
  alert(`同步完成: 上传 ${result?.uploaded || 0}, 下载 ${result?.downloaded || 0}`);
});

document.getElementById('btnResetSettings').addEventListener('click', () => {
  document.getElementById('settingLanguage').value = 'system';
  document.getElementById('settingDeviceName').value = '';
  document.getElementById('settingEyeRest').checked = true;
  document.getElementById('settingPosture').checked = true;
  // Posture interval derived
  document.getElementById('settingMeetingMode').checked = false;
  document.getElementById('settingOvertime').checked = true;
  alert('已重置为默认值');
});

// ============================================================
// Modals
// ============================================================

// Overtime alert
window.sgAPI.onReminderEvent?.((event) => {
  if (event.type === 'overtimeAlert') {
    showOvertimeModal(event.totalSeconds, event.plannedSeconds, event.isFirst);
  }
});

// Listen for IPC events
if (typeof require !== 'undefined') {
  const { ipcRenderer } = require('electron');
  ipcRenderer.on('overtimeAlert', (_, data) => {
    showOvertimeModal(data.totalSeconds, data.plannedSeconds, data.isFirst);
  });

  ipcRenderer.on('weeklySummary', (_, data) => {
    showWeeklySummaryModal(data);
  });
}

function showOvertimeModal(total, planned, isFirst) {
  const modal = document.getElementById('overtimeModal');
  document.getElementById('overtimeTotal').textContent = formatDuration(total);
  document.getElementById('overtimePlanned').textContent = formatDuration(planned);
  document.getElementById('overtimeExceeded').textContent = formatDuration(total - planned);
  document.getElementById('overtimeEmoji').textContent = isFirst ? '⚠️' : '⏰';
  document.getElementById('overtimeTip').style.display = isFirst ? '' : 'none';
  modal.style.display = 'flex';

  document.getElementById('btnOvertimeOk').onclick = () => {
    modal.style.display = 'none';
  };
}

function showWeeklySummaryModal(data) {
  const modal = document.getElementById('weeklySummaryModal');
  const content = document.getElementById('weeklySummaryContent');
  content.innerHTML = `
    <p style="margin-bottom:12px">${data.weekStart} ~ ${data.weekEnd}</p>
    <p>⏱️ 总用时: <strong>${formatDuration(data.totalSeconds)}</strong></p>
    <p>📊 日均: <strong>${formatDuration(data.avgSeconds)}</strong></p>
    <p style="color:var(--text-muted);font-size:13px;margin-top:12px">💡 建议本周保持健康用屏习惯</p>
  `;
  modal.style.display = 'flex';

  document.getElementById('btnWeeklyOk').onclick = () => {
    modal.style.display = 'none';
  };
}

// ============================================================
// Helpers
// ============================================================

function getMonday(dateStr) {
  const d = new Date(dateStr + 'T00:00:00');
  const day = d.getDay();
  const diff = day === 0 ? 6 : day - 1;
  d.setDate(d.getDate() - diff);
  return d.toISOString().split('T')[0];
}

function addDays(dateStr, days) {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + days);
  return d.toISOString().split('T')[0];
}
