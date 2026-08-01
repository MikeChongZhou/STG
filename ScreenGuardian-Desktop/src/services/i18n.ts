/**
 * Internationalization for ScreenGuardian Desktop
 * Matches the Flutter mobile i18n.dart exactly
 */

export type Lang = 'zh-CN' | 'en';

let _lang: Lang = 'zh-CN';

export function setLanguage(lang: string): void {
  if (lang === 'zh-CN' || lang === 'zh') {
    _lang = 'zh-CN';
  } else if (lang === 'en') {
    _lang = 'en';
  } else if (lang === 'system') {
    const sysLang = process.env.LANG || process.env.LC_ALL || 'en';
    _lang = sysLang.startsWith('zh') ? 'zh-CN' : 'en';
  }
}

export function getLang(): Lang {
  return _lang;
}

export function isZh(): boolean {
  return _lang.startsWith('zh');
}

const strings: Record<string, Record<Lang, string>> = {
  'app.name': { 'zh-CN': 'ScreenGuardian 屏幕守护者', 'en': 'ScreenGuardian' },
  'app.running': { 'zh-CN': '运行中', 'en': 'Running' },

  'menu.report': { 'zh-CN': '报告', 'en': 'Report' },
  'menu.settings': { 'zh-CN': '设置', 'en': 'Settings' },
  'menu.tracking': { 'zh-CN': '跟踪', 'en': 'Tracking' },
  'menu.about': { 'zh-CN': '关于', 'en': 'About' },
  'menu.exit': { 'zh-CN': '退出', 'en': 'Exit' },
  'menu.show': { 'zh-CN': '显示主窗口', 'en': 'Show Window' },
  'menu.plan': { 'zh-CN': '周计划', 'en': 'Weekly Plan' },

  'eye_rest.title': { 'zh-CN': '用眼休息时间到了', 'en': 'Time for an Eye Break' },
  'eye_rest.message': { 'zh-CN': '请看向 20 英尺（约 6 米）外的物体，持续 20 秒', 'en': 'Look at something 20 feet (6m) away for 20 seconds' },
  'eye_rest.close': { 'zh-CN': '关闭', 'en': 'Close' },
  'eye_rest.ready': { 'zh-CN': '可以关闭了', 'en': 'Ready to close' },
  'eye_rest.countdown': { 'zh-CN': '倒计时', 'en': 'Countdown' },
  'eye_rest.waiting': { 'zh-CN': '请稍候...', 'en': 'Please wait...' },

  'posture.title': { 'zh-CN': '姿势切换时间到了', 'en': 'Time to Change Posture' },
  'posture.message': { 'zh-CN': '请切换您的坐姿/站姿', 'en': 'Please switch between sitting and standing' },
  'posture.health_tip': { 'zh-CN': '久坐伤身，适时站立活动有益健康', 'en': 'Sitting too long is harmful. Stand up and move!' },
  'posture.confirm': { 'zh-CN': '已完成切换', 'en': 'Done' },

  'report.title': { 'zh-CN': '屏幕用时报告', 'en': 'Screen Time Report' },
  'report.daily': { 'zh-CN': '日报', 'en': 'Daily' },
  'report.range': { 'zh-CN': '多日报', 'en': 'Date Range' },
  'report.total_time': { 'zh-CN': '总用时', 'en': 'Total Time' },
  'report.daily_average': { 'zh-CN': '日均用时', 'en': 'Daily Average' },
  'report.session_detail': { 'zh-CN': '时段明细', 'en': 'Session Details' },
  'report.empty': { 'zh-CN': '暂无数据', 'en': 'No data' },
  'report.daily_breakdown': { 'zh-CN': '每日明细', 'en': 'Daily Breakdown' },

  'settings.title': { 'zh-CN': '设置', 'en': 'Settings' },
  'settings.language': { 'zh-CN': '界面语言', 'en': 'Language' },
  'settings.language_system': { 'zh-CN': '跟随系统', 'en': 'Follow System' },
  'settings.device_name': { 'zh-CN': '设备名称', 'en': 'Device Name' },
  'settings.eye_rest': { 'zh-CN': '用眼休息提醒', 'en': 'Eye Rest Reminder' },
  'settings.posture': { 'zh-CN': '姿势切换提醒', 'en': 'Posture Change Reminder' },
  'settings.posture_interval': { 'zh-CN': '姿势切换间隔', 'en': 'Posture Interval' },
  'settings.meeting_mode': { 'zh-CN': '会议模式', 'en': 'Meeting Mode' },
  'settings.meeting_mode_desc': { 'zh-CN': '开启后，休息提醒弹窗将显示关闭按钮', 'en': 'Show close button on break reminders' },
  'settings.overtime': { 'zh-CN': '超时提醒', 'en': 'Overtime Reminder' },
  'settings.save': { 'zh-CN': '保存', 'en': 'Save' },
  'settings.saved': { 'zh-CN': '设置已保存 ✓', 'en': 'Settings saved ✓' },
  'settings.sync_path': { 'zh-CN': '网盘同步路径', 'en': 'Sync Folder Path' },
  'settings.auto_start': { 'zh-CN': '开机自启', 'en': 'Auto-start on boot' },
  'settings.auto_start_desc': { 'zh-CN': '系统启动时自动运行 ScreenGuardian', 'en': 'Run ScreenGuardian when computer starts' },

  'tracking.title': { 'zh-CN': 'LLM Ranking', 'en': 'LLM Ranking' },
  'tracking.refresh': { 'zh-CN': '刷新数据', 'en': 'Refresh' },
  'tracking.model': { 'zh-CN': '模型', 'en': 'Model' },
  'tracking.provider': { 'zh-CN': '提供商', 'en': 'Provider' },
  'tracking.prompt_tokens': { 'zh-CN': 'Prompt Tokens', 'en': 'Prompt Tokens' },
  'tracking.completion_tokens': { 'zh-CN': 'Output Tokens', 'en': 'Output Tokens' },
  'tracking.weekly_revenue': { 'zh-CN': 'Weekly Revenue', 'en': 'Weekly Revenue' },
  'tracking.source': { 'zh-CN': '数据来源', 'en': 'Source' },

  'about.developer': { 'zh-CN': '开发者：TimberTrail', 'en': 'Developer: TimberTrail' },
  'about.version': { 'zh-CN': '版本：V{version}', 'en': 'Version: V{version}' },
  'about.license': { 'zh-CN': '免费使用', 'en': 'Free to use' },
  'about.description': { 'zh-CN': '跨平台屏幕用时管理工具，守护您的眼睛和健康', 'en': 'Cross-platform screen time manager' },
  'about.p2p_title': { 'zh-CN': '📡 隐私与同步说明', 'en': '📡 Privacy & Sync' },
  'about.subtitle': { 'zh-CN': '屏幕守护者', 'en': 'Screen Time Guardian' },

  'about.p2p_1': { 'zh-CN': '1. 本应用使用 P2P 局域网同步设备数据并计算总屏幕用时。请在每台设备上设置相同的同步码。', 'en': '1. This app uses P2P to sync your devices and calculate your total screen time. Set the same sync code in every app, and avoid using the default code.' },
  'about.p2p_2': { 'zh-CN': '2. 本应用不使用云存储，所有数据仅保存在您的本地设备上。', 'en': '2. This app does not use cloud data. All data stays on your local devices.' },
  'about.p2p_3': { 'zh-CN': '3. 只有您批准的设备才能进行数据同步。', 'en': '3. Only devices you approve can sync.' },

  'plan.title': { 'zh-CN': '周计划管理', 'en': 'Weekly Plan' },
  'plan.set': { 'zh-CN': '设定计划', 'en': 'Set Plan' },
  'plan.daily_target': { 'zh-CN': '每日计划用时', 'en': 'Daily Time Target' },
  'plan.no_plan': { 'zh-CN': '尚未设定本周计划', 'en': 'No plan set for this week' },
  'plan.auto_fill': { 'zh-CN': '根据上周数据自动填入', 'en': 'Auto-filled from last week' },
  'plan.manual': { 'zh-CN': '手动设定', 'en': 'Manually set' },
  'plan.week_progress': { 'zh-CN': '本周进度', 'en': 'Week Progress' },
  'plan.saved': { 'zh-CN': '计划已保存 ✓', 'en': 'Plan saved ✓' },

  'overtime.title': { 'zh-CN': '屏幕用时已超计划', 'en': 'Screen Time Exceeded Plan' },
  'overtime.acknowledge': { 'zh-CN': '我知道了', 'en': 'Got it' },
  'overtime.exceeded': { 'zh-CN': '已超出', 'en': 'Exceeded by' },
  'overtime.continue': { 'zh-CN': '继续使用', 'en': 'Continue' },
  'overtime.take_break': { 'zh-CN': '休息一下', 'en': 'Take a Break' },

  'weekly.title': { 'zh-CN': '上周用时总结', 'en': 'Last Week Summary' },
  'weekly.total': { 'zh-CN': '总用时', 'en': 'Total' },
  'weekly.daily_avg': { 'zh-CN': '日均', 'en': 'Daily avg' },
  'weekly.tip': { 'zh-CN': '💡 建议本周保持健康用屏习惯', 'en': '💡 Keep healthy screen habits this week' },

  'combined.title': { 'zh-CN': '姿势切换 + 用眼休息', 'en': 'Posture Change + Eye Break' },
  'combined.posture_msg': { 'zh-CN': '请切换坐姿/站姿，适当活动身体', 'en': 'Switch sitting/standing position and move around' },
  'combined.eye_msg': { 'zh-CN': '请看向 20 英尺（约 6 米）外的物体，持续 20 秒', 'en': 'Look at something 20 feet (6m) away for 20 seconds' },
  'combined.countdown_label': { 'zh-CN': '请完成姿势切换和眼部休息', 'en': 'Complete posture change and eye rest' },
  'combined.waiting': { 'zh-CN': '请完成姿势切换和眼部休息...', 'en': 'Please complete posture change and eye rest...' },

  'stop_reason.eye_rest': { 'zh-CN': '用眼休息', 'en': 'Eye Rest' },
  'stop_reason.posture_change': { 'zh-CN': '姿势切换', 'en': 'Posture Change' },
  'stop_reason.lock_screen': { 'zh-CN': '锁屏', 'en': 'Lock Screen' },
  'stop_reason.screensaver': { 'zh-CN': '屏保', 'en': 'Screensaver' },
  'stop_reason.standby': { 'zh-CN': '待机', 'en': 'Standby' },
  'stop_reason.shutdown': { 'zh-CN': '关机', 'en': 'Shutdown' },
  'stop_reason.user_exit': { 'zh-CN': '用户退出', 'en': 'User Exit' },
  'stop_reason.meeting_override': { 'zh-CN': '会议模式关闭', 'en': 'Meeting Override' },

  'common.ok': { 'zh-CN': '确定', 'en': 'OK' },
  'common.cancel': { 'zh-CN': '取消', 'en': 'Cancel' },
  'common.save': { 'zh-CN': '保存', 'en': 'Save' },
  'common.close': { 'zh-CN': '关闭', 'en': 'Close' },
};

export function t(key: string, vars?: Record<string, string>): string {
  const entry = strings[key];
  if (!entry) return key;
  let text = entry[_lang] || entry['en'] || key;
  if (vars) {
    Object.entries(vars).forEach(([k, v]) => {
      text = text.replace(new RegExp(`\\{${k}\\}`, 'g'), v);
    });
  }
  return text;
}

export function translateStopReason(reason: string): string {
  return t(`stop_reason.${reason}`);
}

export function formatDuration(seconds: number): string {
  return _lang.startsWith('zh')
    ? formatDurationZh(seconds)
    : formatDurationEn(seconds);
}

function formatDurationZh(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0 && m > 0) return `${h}小时${m}分钟`;
  if (h > 0) return `${h}小时`;
  if (m > 0) return `${m}分钟`;
  return '不到1分钟';
}

function formatDurationEn(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0 && m > 0) return `${h}h ${m}m`;
  if (h > 0) return `${h}h`;
  if (m > 0) return `${m}m`;
  return '<1m';
}

export function formatTokens(n: number | null): string {
  if (n == null) return '-';
  if (n >= 1e9) return `${(n / 1e9).toFixed(1)}B`;
  if (n >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (n >= 1e3) return `${(n / 1e3).toFixed(1)}K`;
  return String(n);
}

export function formatRevenue(n: number | null): string {
  if (n == null) return '-';
  return `$${n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;
}
