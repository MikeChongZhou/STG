/**
 * Time utilities for ScreenGuardian Desktop
 * Matches the Flutter mobile time_utils.dart exactly
 */

export function todayDate(): string {
  const now = new Date();
  return formatDate(now);
}

export function formatDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function formatTime(d: Date): string {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

export function getMonday(dateStr: string): string {
  const d = new Date(`${dateStr}T00:00:00`);
  const day = d.getDay(); // 0=Sun, 1=Mon, ...
  const diff = day === 0 ? 6 : day - 1; // days since Monday
  const monday = new Date(d);
  monday.setDate(monday.getDate() - diff);
  return formatDate(monday);
}

export function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00`);
  d.setDate(d.getDate() + days);
  return formatDate(d);
}

export function getDayOfWeek(dateStr: string): string {
  const d = new Date(`${dateStr}T00:00:00`);
  const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return days[d.getDay() === 0 ? 6 : d.getDay() - 1];
}

export function diffSeconds(start: Date, end: Date): number {
  return Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
}

export function getWeekString(dateStr: string): string {
  const monday = getMonday(dateStr);
  return `${monday.substring(0, 4)}-W${weekOfYear(monday)}`;
}

function weekOfYear(dateStr: string): number {
  const d = new Date(`${dateStr}T00:00:00`);
  const firstDay = new Date(d.getFullYear(), 0, 1);
  const firstMonday = new Date(firstDay);
  firstMonday.setDate(firstMonday.getDate() + ((8 - firstDay.getDay()) % 7));
  if (d < firstMonday) return 1;
  return Math.floor((d.getTime() - firstMonday.getTime()) / (7 * 24 * 60 * 60 * 1000)) + 1;
}

export function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0 && m > 0) return `${h}小时${m}分钟`;
  if (h > 0) return `${h}小时`;
  if (m > 0) return `${m}分钟`;
  return '不到1分钟';
}

export function formatDurationEn(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0 && m > 0) return `${h}h ${m}m`;
  if (h > 0) return `${h}h`;
  if (m > 0) return `${m}m`;
  return '<1m';
}
