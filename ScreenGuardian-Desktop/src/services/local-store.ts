/**
 * Local Store - File-based JSON persistence layer
 * Data format matches ScreenGuardian Mobile for cross-platform sync
 */

import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { app } from 'electron';
import {
  ScreenSession, DailySummary, WeeklyPlan, DeviceInfo, AppConfig, AppState,
  PlatformType, StopReason
} from './types';
import { todayDate, formatDate } from '../utils/time-utils';

const APP_VERSION: string = require('../../../package.json').version;

export class LocalStore {
  private dataDir: string;
  private _deviceInfo!: DeviceInfo;
  private _config!: AppConfig;
  private _state!: AppState;

  constructor() {
    // Store data next to the executable (as noted in DESIGN.md)
    const exeDir = path.dirname(process.execPath);
    this.dataDir = path.join(exeDir, 'screenguardian');
    this.ensureDirectories();
    this.loadOrCreateDeviceInfo();
    this.loadOrCreateConfig();
    this.loadOrCreateState();
    this.performCrashRecovery();
  }

  get deviceId(): string { return this._deviceInfo.deviceId; }
  get deviceName(): string { return this._config.deviceName || this._deviceInfo.deviceName; }
  get config(): AppConfig { return this._config; }
  get state(): AppState { return this._state; }
  get deviceInfo(): DeviceInfo { return this._deviceInfo; }
  get dataPath(): string { return this.dataDir; }

  // ============================================================
  // Directory setup
  // ============================================================

  private ensureDirectories(): void {
    const dirs = [
      this.dataDir,
      path.join(this.dataDir, 'sessions'),
      path.join(this.dataDir, 'summaries'),
      path.join(this.dataDir, 'plans'),
      path.join(this.dataDir, 'tracking', 'llm-ranking'),
      path.join(this.dataDir, 'devices'),
    ];
    for (const dir of dirs) {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    }
  }

  // ============================================================
  // File I/O helpers
  // ============================================================

  private readJson(relativePath: string): any | null {
    try {
      const filePath = path.join(this.dataDir, relativePath);
      if (!fs.existsSync(filePath)) return null;
      return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    } catch {
      return null;
    }
  }

  private readJsonList(relativePath: string): any[] {
    try {
      const filePath = path.join(this.dataDir, relativePath);
      if (!fs.existsSync(filePath)) return [];
      return JSON.parse(fs.readFileSync(filePath, 'utf-8')) as any[];
    } catch {
      return [];
    }
  }

  private writeJson(relativePath: string, data: any): void {
    const filePath = path.join(this.dataDir, relativePath);
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    // Atomic write: write to temp file, then rename
    const tmpPath = `${filePath}.tmp`;
    fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf-8');
    fs.renameSync(tmpPath, filePath);
  }

  // ============================================================
  // Device Info
  // ============================================================

  private loadOrCreateDeviceInfo(): void {
    const json = this.readJson('device.json');
    if (json) {
      this._deviceInfo = json as DeviceInfo;
    } else {
      const platform = process.platform === 'win32' ? PlatformType.Windows : PlatformType.MacOS;
      const prefix = process.platform === 'win32' ? 'win' : 'mac';
      const os = require('os');
      this._deviceInfo = {
        deviceId: `dev-${prefix}-${uuidv4().substring(0, 8)}`,
        deviceName: `${os.userInfo().username}的${process.platform === 'win32' ? 'Windows电脑' : 'MacBook'}`,
        platform,
        registeredAt: new Date().toISOString(),
        lastSyncAt: null,
        lastActiveAt: new Date().toISOString(),
        appVersion: APP_VERSION,
      };
      this.writeJson('device.json', this._deviceInfo);
    }
    this._deviceInfo.lastActiveAt = new Date().toISOString();
    this._deviceInfo.appVersion = APP_VERSION;
    this.writeJson('device.json', this._deviceInfo);
  }

  // ============================================================
  // AppConfig
  // ============================================================

  private loadOrCreateConfig(): void {
    const json = this.readJson('config.json');
    if (json) {
      this._config = json as AppConfig;
    } else {
      this._config = {
        language: 'system',
        postureIntervalMinutes: 30,
        trackingTargets: ['llm_ranking'],
        meetingMode: false,
        syncFolderPath: null,
        deviceName: null,
        eyeRestEnabled: true,
        postureEnabled: true,
        overtimeEnabled: true,
        updatedAt: new Date().toISOString(),
        updatedBy: this.deviceId,
      };
      this.writeJson('config.json', this._config);
    }
  }

  async updateConfig(patch: Partial<AppConfig>): Promise<AppConfig> {
    Object.assign(this._config, patch, {
      updatedAt: new Date().toISOString(),
      updatedBy: this.deviceId,
    });
    this.writeJson('config.json', this._config);
    return this._config;
  }

  // ============================================================
  // AppState
  // ============================================================

  private loadOrCreateState(): void {
    const json = this.readJson('state.json');
    if (json) {
      this._state = json as AppState;
    } else {
      this._state = {
        currentSessionId: null,
        eyeRestTimerRemainingMs: null,
        postureTimerRemainingMs: null,
        lastScreenState: 'active',
        meetingMode: false,
        lastWeeklySummaryWeek: null,
        overtimeAlertedToday: false,
        lastOvertimeReminderAt: null,
      };
      this.writeJson('state.json', this._state);
    }
  }

  async updateState(patch: Partial<AppState>): Promise<void> {
    Object.assign(this._state, patch);
    this.writeJson('state.json', this._state);
  }

  // ============================================================
  // Sessions
  // ============================================================

  private monthKey(date: string): string {
    return date.substring(0, 7);
  }

  loadSessions(monthKey: string): ScreenSession[] {
    return this.readJsonList(`sessions/${monthKey}.json`) as ScreenSession[];
  }

  async createSession(startTime?: Date): Promise<ScreenSession> {
    const now = startTime || new Date();
    const session: ScreenSession = {
      id: uuidv4(),
      deviceId: this.deviceId,
      deviceName: this.deviceName,
      platform: this._deviceInfo.platform,
      startTime: now.toISOString(),
      endTime: null,
      durationSeconds: null,
      stopReason: null,
      date: formatDate(now),
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
      version: 1,
    };
    const mk = this.monthKey(session.date);
    const sessions = this.loadSessions(mk);
    sessions.push(session);
    this.writeJson(`sessions/${mk}.json`, sessions);
    await this.updateState({ currentSessionId: session.id });
    return session;
  }

  async endSession(sessionId: string, reason: StopReason, endTime?: Date): Promise<ScreenSession | null> {
    const now = endTime || new Date();
    const mk = this.monthKey(formatDate(now));
    let sessions = this.loadSessions(mk);
    let session = sessions.find(s => s.id === sessionId);

    if (!session) {
      // Try previous month
      const prevDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const prevMk = this.monthKey(formatDate(prevDate));
      const prevSessions = this.loadSessions(prevMk);
      session = prevSessions.find(s => s.id === sessionId);
      if (session) {
        return this.endSessionInList(prevSessions, prevMk, sessionId, reason, now);
      }
      return null;
    }
    return this.endSessionInList(sessions, mk, sessionId, reason, now);
  }

  private endSessionInList(
    sessions: ScreenSession[], monthKey: string,
    sessionId: string, reason: StopReason, endTime: Date
  ): ScreenSession | null {
    const index = sessions.findIndex(s => s.id === sessionId);
    if (index === -1) return null;

    const session = sessions[index];
    session.endTime = endTime.toISOString();
    session.durationSeconds = Math.max(0,
      Math.floor((endTime.getTime() - new Date(session.startTime).getTime()) / 1000));
    session.stopReason = reason;
    session.updatedAt = new Date().toISOString();
    session.version++;

    this.writeJson(`sessions/${monthKey}.json`, sessions);
    this.updateDailySummary(session.date);
    this.updateState({ currentSessionId: null });
    return session;
  }

  async getTodayTotalSeconds(): Promise<number> {
    const today = todayDate();
    const mk = this.monthKey(today);
    const sessions = this.loadSessions(mk);

    // Collect all time intervals for today
    const intervals: [Date, Date][] = [];
    for (const s of sessions) {
      if (s.date === today && s.endTime) {
        intervals.push([new Date(s.startTime), new Date(s.endTime)]);
      }
    }
    // Include current active session
    if (this._state.currentSessionId) {
      const current = sessions.find(s => s.id === this._state.currentSessionId);
      if (current && current.date === today) {
        intervals.push([new Date(current.startTime), new Date()]);
      }
    }

    return this.computeDedupedSeconds(intervals);
  }

  // ============================================================
  // DailySummary
  // ============================================================

  loadSummaries(monthKey: string): DailySummary[] {
    return this.readJsonList(`summaries/${monthKey}.json`) as DailySummary[];
  }

  updateDailySummary(date: string): DailySummary {
    const mk = this.monthKey(date);
    const sessions = this.loadSessions(mk);
    const daySessions = sessions.filter(s => s.date === date && s.endTime != null);
    const summaries = this.loadSummaries(mk);

    // Deduplicate overlapping time intervals across devices
    const intervals: [Date, Date][] = daySessions
      .filter(s => s.endTime)
      .map(s => [new Date(s.startTime), new Date(s.endTime!)] as [Date, Date]);
    const totalSeconds = this.computeDedupedSeconds(intervals);
    const devices = [...new Set(daySessions.map(s => s.deviceId))];
    const sessionIds = daySessions.map(s => s.id);
    const startTimes = daySessions.map(s => new Date(s.startTime)).sort((a, b) => a.getTime() - b.getTime());
    const endTimes = daySessions
      .filter(s => s.endTime)
      .map(s => new Date(s.endTime!))
      .sort((a, b) => a.getTime() - b.getTime());

    const newSummary: DailySummary = {
      date,
      totalSeconds,
      sessionCount: daySessions.length,
      devices,
      firstSessionStart: startTimes.length > 0 ? startTimes[0].toISOString() : null,
      lastSessionEnd: endTimes.length > 0 ? endTimes[endTimes.length - 1].toISOString() : null,
      sessionIds,
      updatedAt: new Date().toISOString(),
    };

    const existingIndex = summaries.findIndex(s => s.date === date);
    if (existingIndex >= 0) {
      summaries[existingIndex] = newSummary;
    } else {
      summaries.push(newSummary);
    }
    this.writeJson(`summaries/${mk}.json`, summaries);
    return newSummary;
  }

  getDailySummary(date: string): DailySummary | null {
    const mk = this.monthKey(date);
    const summaries = this.loadSummaries(mk);
    return summaries.find(s => s.date === date) || null;
  }

  /**
   * Compute total unique seconds from a list of time intervals.
   * Merges overlapping intervals so time is never double-counted.
   * Handles the case where multiple devices record screen time
   * during the same period (e.g., phone + laptop both active 9:00-10:00).
   */
  computeDedupedSeconds(intervals: [Date, Date][]): number {
    if (intervals.length === 0) return 0;

    // Sort by start time
    intervals.sort((a, b) => a[0].getTime() - b[0].getTime());

    // Merge overlapping intervals
    const merged: [Date, Date][] = [[intervals[0][0], intervals[0][1]]];
    for (let i = 1; i < intervals.length; i++) {
      const current = intervals[i];
      const last = merged[merged.length - 1];

      if (current[0].getTime() <= last[1].getTime()) {
        // Overlapping or adjacent — extend
        if (current[1].getTime() > last[1].getTime()) {
          merged[merged.length - 1] = [last[0], current[1]];
        }
      } else {
        // No overlap — new interval
        merged.push([current[0], current[1]]);
      }
    }

    // Sum merged intervals
    let total = 0;
    for (const [start, end] of merged) {
      total += Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
    }
    return total;
  }

  /** Deduped seconds for a date range (for reports) */
  getDedupedTotalSeconds(startDate: string, endDate: string): number {
    const sessions = this.querySessions({ startDate, endDate });
    const intervals: [Date, Date][] = sessions
      .filter(s => s.endTime)
      .map(s => [new Date(s.startTime), new Date(s.endTime!)] as [Date, Date]);
    return this.computeDedupedSeconds(intervals);
  }

  // ============================================================
  // Query helpers
  // ============================================================

  querySessions(opts: { startDate: string; endDate: string; deviceId?: string; stopReason?: StopReason }): ScreenSession[] {
    const months = this.getMonthRange(opts.startDate.substring(0, 7), opts.endDate.substring(0, 7));
    const results: ScreenSession[] = [];
    for (const mk of months) {
      const sessions = this.loadSessions(mk);
      for (const s of sessions) {
        if (s.date < opts.startDate || s.date > opts.endDate) continue;
        if (opts.deviceId && s.deviceId !== opts.deviceId) continue;
        if (opts.stopReason && s.stopReason !== opts.stopReason) continue;
        results.push(s);
      }
    }
    results.sort((a, b) => a.startTime.localeCompare(b.startTime));
    return results;
  }

  querySummaries(opts: { startDate: string; endDate: string }): DailySummary[] {
    const months = this.getMonthRange(opts.startDate.substring(0, 7), opts.endDate.substring(0, 7));
    const results: DailySummary[] = [];
    for (const mk of months) {
      const summaries = this.loadSummaries(mk);
      for (const s of summaries) {
        if (s.date >= opts.startDate && s.date <= opts.endDate) {
          results.push(s);
        }
      }
    }
    results.sort((a, b) => a.date.localeCompare(b.date));
    return results;
  }

  private getMonthRange(startMonth: string, endMonth: string): string[] {
    const months: string[] = [];
    let current = startMonth;
    while (current <= endMonth) {
      months.push(current);
      const [y, m] = current.split('-').map(Number);
      const nextM = m === 12 ? 1 : m + 1;
      const nextY = m === 12 ? y + 1 : y;
      current = `${nextY}-${String(nextM).padStart(2, '0')}`;
    }
    return months;
  }

  // ============================================================
  // Crash Recovery
  // ============================================================

  private performCrashRecovery(): void {
    if (this._state.currentSessionId) {
      const session = this.endSession(this._state.currentSessionId, StopReason.Shutdown);
      if (session) {
        console.log(`[CrashRecovery] Closed orphaned session ${session.id}, duration: ${session.durationSeconds}s`);
      }
      this.updateState({ currentSessionId: null });
    }
  }

  // ============================================================
  // Weekly Plans
  // ============================================================

  loadWeeklyPlans(): WeeklyPlan[] {
    return this.readJsonList('plans/weekly.json') as WeeklyPlan[];
  }

  saveWeeklyPlan(plan: WeeklyPlan): void {
    const plans = this.loadWeeklyPlans();
    const index = plans.findIndex(p => p.weekStart === plan.weekStart);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.push(plan);
    }
    this.writeJson('plans/weekly.json', plans);
  }

  getWeeklyPlan(weekStart: string): WeeklyPlan | null {
    const plans = this.loadWeeklyPlans();
    return plans.find(p => p.weekStart === weekStart) || null;
  }

  // ============================================================
  // Raw I/O for sync
  // ============================================================

  readRawJson(relativePath: string): any | null {
    return this.readJson(relativePath);
  }

  writeRawJson(relativePath: string, data: any): void {
    this.writeJson(relativePath, data);
  }
}
