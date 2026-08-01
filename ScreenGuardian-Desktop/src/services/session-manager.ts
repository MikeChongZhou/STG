/**
 * Session Manager - Core screen time recording engine
 * Tracks screen active/locked states and manages sessions
 */

import { LocalStore } from './local-store';
import { ScreenSession, StopReason } from './types';
import { todayDate } from '../utils/time-utils';

export class SessionManager {
  private store: LocalStore;
  private currentSession: ScreenSession | null = null;
  private currentSessionStart: Date | null = null;

  constructor(store: LocalStore) {
    this.store = store;
  }

  init(): void {
    const state = this.store.state;
    if (state.currentSessionId) {
      console.log('[SessionManager] Recovered from crash, session was closed');
    }
  }

  async startNewSession(): Promise<ScreenSession> {
    const session = await this.store.createSession();
    this.currentSession = session;
    this.currentSessionStart = new Date(session.startTime);
    return session;
  }

  async pauseCurrentSession(reason: StopReason): Promise<ScreenSession | null> {
    if (!this.currentSession) return null;

    const now = new Date();
    const elapsed = Math.floor((now.getTime() - this.currentSessionStart!.getTime()) / 1000);

    // Discard sessions shorter than 60 seconds
    if (elapsed < 60) {
      this.currentSession = null;
      this.currentSessionStart = null;
      return null;
    }

    const session = await this.store.endSession(this.currentSession.id, reason, now);
    this.currentSession = null;
    this.currentSessionStart = null;
    return session;
  }

  getCurrentElapsedSeconds(): number {
    if (!this.currentSession || !this.currentSessionStart) return 0;
    return Math.floor((Date.now() - this.currentSessionStart.getTime()) / 1000);
  }

  async getTodayTotalSeconds(): Promise<number> {
    return this.store.getTodayTotalSeconds();
  }

  get hasActiveSession(): boolean {
    return this.currentSession !== null;
  }

  get activeSession(): ScreenSession | null {
    return this.currentSession;
  }

  dispose(): void {
    // Cleanup handled by main process
  }
}
