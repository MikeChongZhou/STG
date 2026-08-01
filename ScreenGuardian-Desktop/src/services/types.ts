/**
 * Core type definitions for ScreenGuardian Desktop
 * Matches the Flutter mobile models/types.dart exactly
 */

export enum PlatformType {
  Windows = 'windows',
  MacOS = 'macos',
  AndroidPhone = 'androidPhone',
  AndroidPad = 'androidPad',
  Iphone = 'iphone',
  Ipad = 'ipad',
}

export enum StopReason {
  EyeRest = 'eyeRest',
  PostureChange = 'postureChange',
  LockScreen = 'lockScreen',
  Screensaver = 'screensaver',
  Standby = 'standby',
  Shutdown = 'shutdown',
  UserExit = 'userExit',
  MeetingOverride = 'meetingOverride',
}

export interface ScreenSession {
  id: string;
  deviceId: string;
  deviceName: string;
  platform: PlatformType;
  startTime: string; // ISO 8601
  endTime: string | null;
  durationSeconds: number | null;
  stopReason: StopReason | null;
  date: string; // YYYY-MM-DD
  createdAt: string;
  updatedAt: string;
  version: number;
}

export interface DailySummary {
  date: string;
  totalSeconds: number;
  sessionCount: number;
  devices: string[];
  firstSessionStart: string | null;
  lastSessionEnd: string | null;
  sessionIds: string[];
  updatedAt: string;
}

export interface WeeklyPlan {
  weekStart: string; // YYYY-MM-DD (Monday)
  plannedDailyMinutes: number;
  source: 'user_input' | 'auto_from_last_week';
  createdAt: string;
}

export interface DeviceInfo {
  deviceId: string;
  deviceName: string;
  platform: PlatformType;
  registeredAt: string;
  lastSyncAt: string | null;
  lastActiveAt: string | null;
  appVersion: string;
}

export interface AppConfig {
  language: string;
  postureIntervalMinutes: number;
  trackingTargets: string[];
  meetingMode: boolean;
  syncFolderPath: string | null;
  deviceName: string | null;
  eyeRestEnabled: boolean;
  postureEnabled: boolean;
  overtimeEnabled: boolean;
  updatedAt: string;
  updatedBy: string;
}

export interface AppState {
  currentSessionId: string | null;
  eyeRestTimerRemainingMs: number | null;
  postureTimerRemainingMs: number | null;
  lastScreenState: string;
  meetingMode: boolean;
  lastWeeklySummaryWeek: string | null;
  overtimeAlertedToday: boolean;
  lastOvertimeReminderAt: string | null;
}

export interface RankingEntry {
  rank: number;
  modelId: string;
  modelName: string;
  provider: string;
  promptTokens: number | null;
  completionTokens: number | null;
  inputPricePerMToken: number | null;
  outputPricePerMToken: number | null;
  weeklyRevenue: number | null;
  requestCount: number | null;
}

export interface LLMRankingRecord {
  weekStart: string;
  weekEnd: string;
  fetchedAt: string;
  fetchedBy: string;
  source: string;
  data: RankingEntry[];
}

export interface SyncMeta {
  lastGlobalSyncAt: string;
  devices: Record<string, {
    lastSyncAt: string;
    lastSessionSynced: string | null;
    version: number;
  }>;
}
