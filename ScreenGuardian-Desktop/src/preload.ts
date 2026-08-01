/**
 * Preload script - Secure bridge between main process and renderer
 * Exposes safe APIs to the UI via contextBridge
 */

import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('sgAPI', {
  // Session data
  getCurrentElapsed: () => ipcRenderer.invoke('getCurrentElapsed'),
  getTodayTotal: () => ipcRenderer.invoke('getTodayTotal'),

  // Reports
  querySessions: (opts: any) => ipcRenderer.invoke('querySessions', opts),
  querySummaries: (opts: any) => ipcRenderer.invoke('querySummaries', opts),

  // Settings
  getConfig: () => ipcRenderer.invoke('getConfig'),
  updateConfig: (patch: any) => ipcRenderer.invoke('updateConfig', patch),

  // Weekly Plans
  getWeeklyPlan: (weekStart: string) => ipcRenderer.invoke('getWeeklyPlan', weekStart),
  saveWeeklyPlan: (plan: any) => ipcRenderer.invoke('saveWeeklyPlan', plan),
  loadWeeklyPlans: () => ipcRenderer.invoke('loadWeeklyPlans'),

  // Tracking / Ranking
  fetchRanking: () => ipcRenderer.invoke('fetchRanking'),

  // P2P Sync (mDNS-based)
  getSyncStatus: () => ipcRenderer.invoke('getSyncStatus'),
  startP2P: (code?: string) => ipcRenderer.invoke('startP2P', code),
  stopP2P: () => ipcRenderer.invoke('stopP2P'),
  triggerSync: () => ipcRenderer.invoke('triggerSync'),
  pairDevice: (deviceId: string, code: string) => ipcRenderer.invoke('pairDevice', deviceId, code),
  approveDevice: (deviceId: string) => ipcRenderer.invoke('approveDevice', deviceId),
  getDiscoveredDevices: () => ipcRenderer.invoke('getDiscoveredDevices'),

  // Device
  getDeviceInfo: () => ipcRenderer.invoke('getDeviceInfo'),

  // System
  getPlatform: () => process.platform,
  getVersion: () => ipcRenderer.invoke('getVersion'),

  // Window controls
  minimizeToTray: () => ipcRenderer.invoke('minimizeToTray'),

  // Reminder events from main
  onReminderEvent: (callback: (event: any) => void) => {
    ipcRenderer.on('reminderEvent', (_, event) => callback(event));
  },
  closeReminder: () => ipcRenderer.invoke('closeReminder'),
});
