/**
 * Auto-start - Register/unregister app for auto-start on boot
 * Windows: Registry Run Key
 * macOS: Login Items (launchd plist)
 */

import * as path from 'path';
import { exec } from 'child_process';
import { app } from 'electron';

const APP_NAME = 'ScreenGuardian';

export function isEnabled(): boolean {
  const loginItem = app.getLoginItemSettings();
  return loginItem.openAtLogin;
}

export function enable(): void {
  app.setLoginItemSettings({
    openAtLogin: true,
    name: APP_NAME,
    // macOS specific
    path: process.execPath,
    args: ['--hidden'],
  });
  console.log('[AutoStart] Enabled');
}

export function disable(): void {
  app.setLoginItemSettings({
    openAtLogin: false,
    name: APP_NAME,
  });
  console.log('[AutoStart] Disabled');
}

export function toggle(enabled: boolean): void {
  if (enabled) {
    enable();
  } else {
    disable();
  }
}
