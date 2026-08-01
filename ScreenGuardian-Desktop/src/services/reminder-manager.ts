/**
 * Reminder Manager - Unified eye rest + posture change reminders
 *
 * Design:
 *   - Single timer fires every 20 minutes (eye rest interval)
 *   - Every 2nd trigger (= 40 min) also includes posture change
 *   - Combined reminder: change posture + look 20ft away for 20s
 */

import { EventEmitter } from 'events';
import { LocalStore } from './local-store';

export enum ReminderType {
  EyeRest = 'eyeRest',
  EyeRestAndPosture = 'eyeRestAndPosture',
}

export interface ReminderEvent {
  type: ReminderType;
  countdownSeconds: number;
  meetingMode: boolean;
  isCombined: boolean;
}

export class ReminderManager extends EventEmitter {
  private store: LocalStore;
  private timer: NodeJS.Timeout | null = null;
  private _active = false;
  private _triggerCount = 0;

  private eyeRestIntervalMs: number;
  private meetingMode: boolean;
  private eyeRestEnabled: boolean;
  private postureEnabled: boolean;

  constructor(store: LocalStore) {
    super();
    this.store = store;
    this.eyeRestIntervalMs = 20 * 60 * 1000; // 20 minutes
    this.meetingMode = store.config.meetingMode;
    this.eyeRestEnabled = store.config.eyeRestEnabled;
    this.postureEnabled = store.config.postureEnabled;
  }

  reloadSettings(): void {
    const config = this.store.config;
    this.meetingMode = config.meetingMode;
    this.eyeRestEnabled = config.eyeRestEnabled;
    this.postureEnabled = config.postureEnabled;
    this.resetTimer();
  }

  startTimers(): void {
    if (this.eyeRestEnabled) this.startTimer();
  }

  stopTimers(): void {
    if (this.timer) { clearTimeout(this.timer); this.timer = null; }
    this._active = false;
  }

  resetTimer(): void {
    this.stopTimers();
    this.startTimers();
  }

  private startTimer(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      if (this._active) return;
      this._active = true;
      this._triggerCount++;

      const isPostureCycle = this.postureEnabled && (this._triggerCount % 2 === 0);

      this.emit('reminder', {
        type: isPostureCycle ? ReminderType.EyeRestAndPosture : ReminderType.EyeRest,
        countdownSeconds: isPostureCycle ? 120 : 20,
        meetingMode: this.meetingMode,
        isCombined: isPostureCycle,
      } as ReminderEvent);
    }, this.eyeRestIntervalMs);
  }

  onDialogClosed(): void {
    this._active = false;
    this.startTimer();
  }

  // Legacy compat
  onEyeRestDialogClosed(): void { this.onDialogClosed(); }
  onPostureDialogClosed(): void { this.onDialogClosed(); }

  get isActive(): boolean { return this._active; }
  get isEyeRestActive(): boolean { return this._active; }
  get isPostureActive(): boolean { return false; }
  get hasActiveReminder(): boolean { return this._active; }

  dispose(): void {
    this.stopTimers();
    this.removeAllListeners();
  }
}
