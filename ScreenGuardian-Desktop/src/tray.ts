/**
 * System Tray - Menu bar / system tray icon and menu
 * macOS: NSStatusItem (menu bar)
 * Windows: System Tray (notification area)
 */

import { Tray, Menu, nativeImage, BrowserWindow, app } from 'electron';
import * as path from 'path';
import { LocalStore } from '../services/local-store';
import { t, isZh, formatDuration, getLang } from '../services/i18n';
import { todayDate } from '../utils/time-utils';

export class AppTray {
  private tray: Tray | null = null;
  private store: LocalStore;
  private mainWindow: BrowserWindow | null = null;
  private updateTimer: NodeJS.Timeout | null = null;

  // Callbacks
  onShowWindow: (() => void) | null = null;
  onExit: (() => void) | null = null;

  constructor(store: LocalStore) {
    this.store = store;
  }

  setMainWindow(win: BrowserWindow): void {
    this.mainWindow = win;
  }

  create(): void {
    // Create a simple 16x16 tray icon using nativeImage
    const icon = this.createTrayIcon();
    this.tray = new Tray(icon);
    this.tray.setToolTip('ScreenGuardian');
    this.updateContextMenu();

    // Update menu every 30 seconds
    this.updateTimer = setInterval(() => this.updateContextMenu(), 30000);

    // Click to show window
    this.tray.on('click', () => {
      this.onShowWindow?.();
    });
  }

  private createTrayIcon(): Electron.NativeImage {
    // Create a simple colored icon programmatically
    // In production, use a proper .ico/.png file
    const size = 16;
    const canvas = Buffer.alloc(size * size * 4);

    // Draw a shield shape (simplified)
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const idx = (y * size + x) * 4;
        // Shield shape: blue (#1A237E)
        const cx = x - size / 2;
        const cy = y - size / 2;
        const inShield = Math.abs(cx) < (size / 2 - 2) && cy > -size / 2 + 1 && cy < size / 2 - 1;
        if (inShield) {
          canvas[idx] = 0x1A;     // R
          canvas[idx + 1] = 0x23; // G
          canvas[idx + 2] = 0x7E; // B
          canvas[idx + 3] = 0xFF; // A
        } else {
          canvas[idx] = 0;
          canvas[idx + 1] = 0;
          canvas[idx + 2] = 0;
          canvas[idx + 3] = 0;
        }
      }
    }

    return nativeImage.createFromBuffer(canvas, { width: size, height: size });
  }

  async updateContextMenu(): Promise<void> {
    if (!this.tray) return;

    const todayTotal = await this.store.getTodayTotalSeconds();
    const plan = this.store.getWeeklyPlan(
      require('../utils/time-utils').getMonday(todayDate())
    );

    const menuItems: Electron.MenuItemConstructorOptions[] = [
      {
        label: `🛡️ ScreenGuardian`,
        enabled: false,
      },
      { type: 'separator' },
      {
        label: `⏱️ ${isZh() ? '今日用时' : 'Today'}: ${formatDuration(todayTotal)}`,
        enabled: false,
      },
    ];

    if (plan) {
      const planned = plan.plannedDailyMinutes * 60;
      const over = todayTotal > planned;
      menuItems.push({
        label: `🎯 ${isZh() ? '计划' : 'Plan'}: ${formatDuration(planned)}${over ? ` (${isZh() ? '已超出' : 'OVER'})` : ''}`,
        enabled: false,
      });
    }

    menuItems.push(
      { type: 'separator' },
      {
        label: `📊 ${t('menu.report')}`,
        click: () => this.onShowWindow?.(),
      },
      {
        label: `🎯 ${t('menu.plan')}`,
        click: () => this.onShowWindow?.(),
      },
      {
        label: `📡 ${t('menu.tracking')}`,
        click: () => this.onShowWindow?.(),
      },
      {
        label: `⚙️ ${t('menu.settings')}`,
        click: () => this.onShowWindow?.(),
      },
      { type: 'separator' },
      {
        label: `📤 ${isZh() ? '显示主窗口' : 'Show Window'}`,
        click: () => this.onShowWindow?.(),
      },
      { type: 'separator' },
      {
        label: `❌ ${t('menu.exit')}`,
        click: () => this.onExit?.(),
      }
    );

    const contextMenu = Menu.buildFromTemplate(menuItems);
    this.tray.setContextMenu(contextMenu);

    // Update tooltip
    this.tray.setToolTip(`ScreenGuardian - ${isZh() ? '今日' : 'Today'}: ${formatDuration(todayTotal)}`);
  }

  destroy(): void {
    if (this.updateTimer) {
      clearInterval(this.updateTimer);
      this.updateTimer = null;
    }
    if (this.tray) {
      this.tray.destroy();
      this.tray = null;
    }
  }
}
