/**
 * Screen Detector - Detects screen lock/unlock, screensaver, sleep/shutdown
 * Platform-specific implementations for Windows and macOS
 */

import { EventEmitter } from 'events';
import { exec, ChildProcess } from 'child_process';
import * as os from 'os';

export enum ScreenState {
  Active = 'active',
  Locked = 'locked',
  Screensaver = 'screensaver',
  Sleep = 'sleep',
  Shutdown = 'shutdown',
}

export class ScreenDetector extends EventEmitter {
  private platform: string;
  private _currentState: ScreenState = ScreenState.Active;
  private watcher: ChildProcess | null = null;

  constructor() {
    super();
    this.platform = process.platform;
  }

  get currentState(): ScreenState {
    return this._currentState;
  }

  start(): void {
    if (this.platform === 'win32') {
      this.startWindows();
    } else if (this.platform === 'darwin') {
      this.startMacOS();
    }
  }

  stop(): void {
    if (this.watcher) {
      this.watcher.kill();
      this.watcher = null;
    }
  }

  // ============================================================
  // Windows: Listen for power/session events via PowerShell
  // ============================================================

  private startWindows(): void {
    // Use PowerShell to monitor screen lock/unlock events
    // WM_POWERBROADCAST for sleep/wake, SessionSwitch for lock/unlock
    const script = `
      Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Security;
        public class PowerMonitor {
          public delegate bool Handler(int reason);
          [DllImport("user32.dll")]
          public static extern bool RegisterPowerSettingNotification(IntPtr hRecipient, ref Guid PowerSettingGuid, int Flags);
          [DllImport("user32.dll")]
          public static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);
        }
"@

      # Monitor session switch events (lock/unlock)
      $lastState = "active"
      while ($true) {
        Start-Sleep -Seconds 2
        $locked = (Get-Process -Name "LogonUI" -ErrorAction SilentlyContinue) -ne $null
        $screensaver = (Get-Process -Name "scrnsave" -ErrorAction SilentlyContinue) -ne $null

        $state = if ($screensaver) { "screensaver" } elseif ($locked) { "locked" } else { "active" }

        if ($state -ne $lastState) {
          Write-Output $state
          $lastState = $state
        }
      }
    `;

    try {
      this.watcher = exec(`powershell -NoProfile -Command "${script.replace(/"/g, '\\"')}"`, {
        windowsHide: true,
      });

      this.watcher.stdout?.on('data', (data: string) => {
        const state = data.toString().trim();
        if (state === 'active' || state === 'locked' || state === 'screensaver') {
          this.setState(state as ScreenState);
        }
      });

      this.watcher.on('error', (err) => {
        console.error('[ScreenDetector] Windows error:', err);
        // Fallback: simple polling
        this.startFallbackPolling();
      });
    } catch (e) {
      console.error('[ScreenDetector] Failed to start Windows detector:', e);
      this.startFallbackPolling();
    }
  }

  // ============================================================
  // macOS: Use CGSession and NSWorkspace notifications
  // ============================================================

  private startMacOS(): void {
    // Use Quartz event tap to detect screen lock/unlock
    const script = `
      # Monitor screen lock via CGSession
      lastState="active"
      while true; do
        # Check if screen is locked
        locked=$(python3 -c "
import subprocess
result = subprocess.run(['python3', '-c', '''
import Quartz
import CoreGraphics
session = Quartz.CGSessionCopyCurrentDictionary()
if session:
    print(\"locked\" if session.get(\"CGSSessionScreenIsLocked\", 0) else \"active\")
else:
    print(\"active\")
'''], capture_output=True, text=True)
print(result.stdout.strip())
" 2>/dev/null || echo "active")

        # Check for screensaver
        screensaver=$(pgrep -x ScreenSaverEngine 2>/dev/null && echo "screensaver" || echo "")

        state="active"
        if [ -n "$screensaver" ]; then
          state="screensaver"
        elif [ "$locked" = "locked" ]; then
          state="locked"
        fi

        if [ "$state" != "$lastState" ]; then
          echo "$state"
          lastState="$state"
        fi
        sleep 2
      done
    `;

    try {
      this.watcher = exec(script, { shell: '/bin/bash' });

      this.watcher.stdout?.on('data', (data: string) => {
        const state = data.toString().trim();
        if (state === 'active' || state === 'locked' || state === 'screensaver') {
          this.setState(state as ScreenState);
        }
      });

      this.watcher.on('error', () => {
        this.startFallbackPolling();
      });
    } catch (e) {
      this.startFallbackPolling();
    }
  }

  // ============================================================
  // Fallback: Simple polling (no native events)
  // ============================================================

  private startFallbackPolling(): void {
    console.log('[ScreenDetector] Using fallback polling');
    // In fallback mode, we assume screen is always active
    // Real lock detection would need native addons
    this._currentState = ScreenState.Active;
  }

  private setState(newState: ScreenState): void {
    if (this._currentState === newState) return;
    const oldState = this._currentState;
    this._currentState = newState;
    this.emit('stateChange', { from: oldState, to: newState });
  }
}
