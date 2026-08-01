/**
 * ScreenGuardian Desktop - Main Entry Point
 * Wires up all services: tray, screen detection, sessions, reminders, P2P sync
 */

import { app, BrowserWindow, ipcMain } from 'electron';
import * as path from 'path';
import { LocalStore } from './services/local-store';
import { SessionManager } from './services/session-manager';
import { ReminderManager, ReminderType, ReminderEvent } from './services/reminder-manager';
import { P2PSyncService } from './services/p2p-sync-service';
import { RankingService } from './services/ranking-service';
import { ScreenDetector, ScreenState } from './platform/screen-detector';
import { AppTray } from './tray';
import { setLanguage, isZh, formatDuration, t } from './services/i18n';
import { todayDate, getMonday, addDays, getWeekString } from './utils/time-utils';
import { StopReason } from './services/types';
import * as autoStart from './platform/auto-start';

const APP_VERSION: string = require('../../package.json').version;

let mainWindow: BrowserWindow | null = null;
let store: LocalStore;
let sessionManager: SessionManager;
let reminderManager: ReminderManager;
let p2pSync: P2PSyncService;
let rankingService: RankingService;
let screenDetector: ScreenDetector;
let tray: AppTray;

// Overtime tracking
let overtimeTimer: NodeJS.Timeout | null = null;
let overtimeAlertedToday = false;
let lastOvertimeReminder: Date | null = null;

// ============================================================
// App Lifecycle
// ============================================================

app.whenReady().then(async () => {
  // Initialize store
  store = new LocalStore();

  // Apply saved language
  const config = store.config;
  if (config.language !== 'system') {
    setLanguage(config.language);
  } else {
    const sysLang = process.env.LANG || process.env.LC_ALL || 'en';
    setLanguage(sysLang.startsWith('zh') ? 'zh-CN' : 'en');
  }

  // Initialize services
  sessionManager = new SessionManager(store);
  sessionManager.init();

  reminderManager = new ReminderManager(store);
  p2pSync = new P2PSyncService(store);
  rankingService = new RankingService();
  screenDetector = new ScreenDetector();

  // Initialize tray
  tray = new AppTray(store);
  tray.onShowWindow = () => showMainWindow();
  tray.onExit = () => quitApp();
  tray.create();

  // Create main window (hidden initially)
  createMainWindow();

  // Start session tracking
  await sessionManager.startNewSession();
  reminderManager.startTimers();

  // Start screen detector
  screenDetector.start();
  screenDetector.on('stateChange', async (event) => {
    console.log(`[Screen] State change: ${event.from} → ${event.to}`);
    if (event.to === ScreenState.Locked || event.to === ScreenState.Screensaver) {
      await sessionManager.pauseCurrentSession(
        event.to === ScreenState.Locked ? StopReason.LockScreen : StopReason.Screensaver
      );
      reminderManager.stopTimers();
    } else if (event.to === ScreenState.Active) {
      if (!sessionManager.hasActiveSession) {
        await sessionManager.startNewSession();
        reminderManager.startTimers();
      }
    }
  });

  // Listen for reminder events
  reminderManager.on('reminder', (event: ReminderEvent) => {
    handleReminder(event);
  });

  // Start P2P mDNS sync service
  try {
    await p2pSync.start();
    console.log('[Main] P2P mDNS sync started');
  } catch (e) {
    console.error('[Main] P2P sync failed to start:', e);
  }

  // Check weekly summary
  checkWeeklySummary();

  // Start overtime monitoring
  startOvertimeCheck();

  // Register IPC handlers
  registerIpcHandlers();

  // Reset overtime flag at midnight
  scheduleOvertimeReset();

  console.log('[Main] ScreenGuardian Desktop started');
});

app.on('window-all-closed', () => {
  // Don't quit - stay in tray
});

// ============================================================
// Main Window
// ============================================================

function createMainWindow(): void {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 700,
    show: false,
    title: 'ScreenGuardian',
    icon: path.join(__dirname, '..', 'ui', 'icons', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, '..', 'ui', 'index.html'));

  mainWindow.on('close', (e) => {
    e.preventDefault();
    mainWindow?.hide();
  });
}

function showMainWindow(): void {
  if (mainWindow) {
    mainWindow.show();
    mainWindow.focus();
    tray.updateContextMenu();
  }
}

function quitApp(): void {
  sessionManager.pauseCurrentSession(StopReason.UserExit);
  reminderManager.dispose();
  screenDetector.stop();
  p2pSync.stop();
  tray.destroy();
  app.quit();
}

// ============================================================
// Reminder Handling
// ============================================================

function handleReminder(event: ReminderEvent): void {
  showReminderWindow(event);
  mainWindow?.webContents.send('reminderEvent', {
    type: event.isCombined ? 'combined' : 'eye_rest',
    countdown: event.countdownSeconds,
  });
}

let reminderWindow: BrowserWindow | null = null;

function showReminderWindow(event: ReminderEvent): void {
  if (reminderWindow) { reminderWindow.focus(); return; }

  const isCombined = event.isCombined;

  reminderWindow = new BrowserWindow({
    width: isCombined ? 440 : 400,
    height: isCombined ? 560 : 500,
    frame: false, alwaysOnTop: true, resizable: false, skipTaskbar: true,
    title: isCombined ? t('combined.title') : t('eye_rest.title'),
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true },
  });

  const emojiHTML = isCombined
    ? `<div style="display:flex;justify-content:center;align-items:center;gap:10px;margin-bottom:16px"><span style="font-size:40px">🧘</span><span style="font-size:22px;color:#9E9E9E">+</span><span style="font-size:40px">👁️</span></div>`
    : `<div class="emoji">👁️</div>`;

  const title = isCombined ? t('combined.title') : t('eye_rest.title');

  const messageHTML = isCombined
    ? `<div style="text-align:left;padding:12px 14px;border-radius:10px;font-size:14px;line-height:1.5;margin-bottom:10px;background:#F3E5F5">🧘 ${t('combined.posture_msg')}</div>
       <div style="text-align:left;padding:12px 14px;border-radius:10px;font-size:14px;line-height:1.5;margin-bottom:16px;background:#E3F2FD">👁️ ${t('combined.eye_msg')}</div>`
    : `<div class="message">${t('eye_rest.message')}</div>`;

  const countdownLabel = isCombined ? t('combined.countdown_label') : t('eye_rest.countdown');
  const waitingText = isCombined ? t('combined.waiting') : t('eye_rest.waiting');
  const readyText = t('eye_rest.ready');
  const closeText = t('eye_rest.close');

  const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f5f5f5;display:flex;justify-content:center;align-items:center;height:100vh;-webkit-app-region:drag}
.card{background:white;border-radius:12px;padding:28px;text-align:center;box-shadow:0 2px 12px rgba(0,0,0,.08);max-width:380px}
.emoji{font-size:56px;margin-bottom:16px}
.message{color:#616161;font-size:14px;line-height:1.6;margin-bottom:24px}
.ring{width:110px;height:110px;margin:0 auto 8px;position:relative}
.ring svg{transform:rotate(-90deg)}
.ring .v{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);font-size:32px;font-weight:700;color:#1A237E}
.lbl{color:#9E9E9E;font-size:13px;margin-bottom:20px}
.btn{background:#1A237E;color:white;border:none;padding:12px 36px;border-radius:6px;font-size:14px;font-weight:500;cursor:pointer;-webkit-app-region:no-drag}
.btn.hidden{display:none}
.wait{color:#9E9E9E;font-size:12px}
</style></head><body><div class="card">
${emojiHTML}
<div style="color:#1A237E;font-size:20px;font-weight:600;margin-bottom:12px">${title}</div>
${messageHTML}
<div class="ring"><svg width="110" height="110">
<circle cx="55" cy="55" r="48" fill="none" stroke="#E0E0E0" stroke-width="6"/>
<circle id="p" cx="55" cy="55" r="48" fill="none" stroke="#1A237E" stroke-width="6" stroke-dasharray="301.6" stroke-dashoffset="0" stroke-linecap="round"/>
</svg><span class="v" id="cd">${event.countdownSeconds}</span></div>
<div class="lbl" id="lb">${countdownLabel}</div>
<button class="btn hidden" id="cb" onclick="window.sgAPI.closeReminder()">${closeText}</button>
<div class="wait" id="wt">${waitingText}</div>
</div><script>
let c=${event.countdownSeconds};const total=${event.countdownSeconds},ci=301.6;
const p=document.getElementById('p'),cd=document.getElementById('cd'),cb=document.getElementById('cb'),wt=document.getElementById('wt');
const iv=setInterval(()=>{c--;cd.textContent=c;p.style.strokeDashoffset=ci*(1-c/total);
if(c<=5)p.style.stroke='#f44336';else if(c<=15)p.style.stroke='#ff9800';
if(c<=0){clearInterval(iv);cd.textContent='✓';cd.style.color='#10B981';cd.style.fontSize='36px';cb.classList.remove('hidden');wt.style.display='none';document.getElementById('lb').textContent='${readyText}';}},1000);
${event.meetingMode ? 'cb.classList.remove("hidden");wt.style.display="none";' : ''}
</script></body></html>`;

  reminderWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);

  reminderWindow.on('closed', () => {
    reminderWindow = null;
    reminderManager.onDialogClosed();
  });

  setTimeout(() => {
    if (reminderWindow) {
      const reason = event.isCombined ? StopReason.PostureChange : StopReason.EyeRest;
      sessionManager.pauseCurrentSession(reason);
      sessionManager.startNewSession();
    }
  }, (event.countdownSeconds + 1) * 1000);
}

// ============================================================
// Weekly Summary
// ============================================================

function checkWeeklySummary(): void {
  const today = todayDate();
  const d = new Date(`${today}T00:00:00`);
  if (d.getDay() !== 1) return;

  const currentWeekStart = getMonday(today);
  const state = store.state;
  if (state.lastWeeklySummaryWeek === getWeekString(today)) return;

  const lastWeekStart = addDays(currentWeekStart, -7);
  const lastWeekEnd = addDays(currentWeekStart, -1);

  const summaries = store.querySummaries({ startDate: lastWeekStart, endDate: lastWeekEnd });
  let totalSeconds = 0;
  for (const s of summaries) totalSeconds += s.totalSeconds;
  const avgSeconds = summaries.length > 0 ? Math.floor(totalSeconds / summaries.length) : 0;

  store.updateState({ lastWeeklySummaryWeek: getWeekString(today) });
  mainWindow?.webContents.send('weeklySummary', { weekStart: lastWeekStart, weekEnd: lastWeekEnd, totalSeconds, avgSeconds });
}

// ============================================================
// Overtime Check
// ============================================================

function startOvertimeCheck(): void {
  overtimeTimer = setInterval(async () => {
    const config = store.config;
    if (!config.overtimeEnabled) return;

    const today = todayDate();
    const monday = getMonday(today);
    const plan = store.getWeeklyPlan(monday);
    if (!plan) return;

    const todayTotal = await sessionManager.getTodayTotalSeconds();
    const plannedSeconds = plan.plannedDailyMinutes * 60;
    if (todayTotal <= plannedSeconds) return;

    if (!overtimeAlertedToday) {
      overtimeAlertedToday = true;
      showOvertimeAlert(todayTotal, plannedSeconds, true);
      lastOvertimeReminder = new Date();
    } else if (lastOvertimeReminder) {
      const minutesSince = Math.floor((Date.now() - lastOvertimeReminder.getTime()) / 60000);
      if (minutesSince >= 25) {
        lastOvertimeReminder = new Date();
        showOvertimeAlert(todayTotal, plannedSeconds, false);
      }
    }
  }, 5 * 60 * 1000);
}

function showOvertimeAlert(totalSeconds: number, plannedSeconds: number, isFirst: boolean): void {
  mainWindow?.webContents.send('overtimeAlert', { totalSeconds, plannedSeconds, isFirst });
}

function scheduleOvertimeReset(): void {
  const now = new Date();
  const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  setTimeout(() => {
    overtimeAlertedToday = false;
    lastOvertimeReminder = null;
    scheduleOvertimeReset();
  }, tomorrow.getTime() - now.getTime());
}

// ============================================================
// IPC Handlers
// ============================================================

function registerIpcHandlers(): void {
  ipcMain.handle('getCurrentElapsed', () => sessionManager.getCurrentElapsedSeconds());
  ipcMain.handle('getTodayTotal', () => sessionManager.getTodayTotalSeconds());

  ipcMain.handle('querySessions', (_, opts) => store.querySessions(opts));
  ipcMain.handle('querySummaries', (_, opts) => store.querySummaries(opts));

  ipcMain.handle('getConfig', () => store.config);
  ipcMain.handle('updateConfig', async (_, patch) => {
    const config = await store.updateConfig(patch);
    reminderManager.reloadSettings();
    if (patch.language) setLanguage(patch.language);
    return config;
  });

  ipcMain.handle('getWeeklyPlan', (_, weekStart) => store.getWeeklyPlan(weekStart));
  ipcMain.handle('saveWeeklyPlan', (_, plan) => { store.saveWeeklyPlan(plan); return true; });
  ipcMain.handle('loadWeeklyPlans', () => store.loadWeeklyPlans());

  ipcMain.handle('fetchRanking', () => rankingService.fetchFromAPI());

  ipcMain.handle('getSyncStatus', () => ({
    running: p2pSync.isRunning,
    paired: p2pSync.isPaired,
    port: p2pSync.serverPort,
    devices: p2pSync.getDiscoveredDevices(),
  }));
  ipcMain.handle('startP2P', async (_, code) => { await p2pSync.start(code); return { running: p2pSync.isRunning, paired: p2pSync.isPaired }; });
  ipcMain.handle('stopP2P', () => p2pSync.stop());
  ipcMain.handle('triggerSync', () => p2pSync.syncWithAll());
  ipcMain.handle('pairDevice', (_, deviceId, code) => p2pSync.pairDevice(deviceId, code));
  ipcMain.handle('approveDevice', (_, deviceId) => p2pSync.approveDevice(deviceId));
  ipcMain.handle('getDiscoveredDevices', () => p2pSync.getDiscoveredDevices());

  ipcMain.handle('getDeviceInfo', () => store.deviceInfo);
  ipcMain.handle('getVersion', () => APP_VERSION);

  ipcMain.handle('minimizeToTray', () => mainWindow?.hide());
  ipcMain.handle('closeReminder', () => reminderWindow?.close());
}
