/// Internationalization for ScreenGuardian Mobile

import '../constants.dart';

class AppStrings {
  static String _lang = 'zh-CN';

  static void setLanguage(String lang) {
    _lang = lang;
  }

  static String get lang => _lang;

  static final Map<String, Map<String, String>> _strings = {
    'app.name': {'zh-CN': 'ScreenGuardian 屏幕守护者', 'en': 'ScreenGuardian'},
    'app.running': {'zh-CN': '运行中', 'en': 'Running'},

    'menu.report': {'zh-CN': '报告', 'en': 'Report'},
    'menu.settings': {'zh-CN': '设置', 'en': 'Settings'},
    'menu.tracking': {'zh-CN': '跟踪', 'en': 'Tracking'},
    'menu.about': {'zh-CN': '关于', 'en': 'About'},
    'menu.exit': {'zh-CN': '退出', 'en': 'Exit'},

    'eye_rest.title': {'zh-CN': '用眼休息时间到了', 'en': 'Time for an Eye Break'},
    'eye_rest.message': {'zh-CN': '请看向 20 英尺（约 6 米）外的物体，持续 20 秒', 'en': 'Look at something 20 feet (6m) away for 20 seconds'},
    'eye_rest.close': {'zh-CN': '关闭', 'en': 'Close'},
    'eye_rest.ready': {'zh-CN': '可以关闭了', 'en': 'Ready to close'},

    'posture.title': {'zh-CN': '姿势切换时间到了', 'en': 'Time to Change Posture'},
    'posture.message': {'zh-CN': '请切换您的坐姿/站姿', 'en': 'Please switch between sitting and standing'},
    'posture.health_tip': {'zh-CN': '久坐伤身，适时站立活动有益健康', 'en': 'Sitting too long is harmful. Stand up and move!'},
    'posture.confirm': {'zh-CN': '已完成切换', 'en': 'Done'},

    'report.title': {'zh-CN': '屏幕用时报告', 'en': 'Screen Time Report'},
    'report.daily': {'zh-CN': '日报', 'en': 'Daily'},
    'report.range': {'zh-CN': '多日报', 'en': 'Date Range'},
    'report.total_time': {'zh-CN': '总用时', 'en': 'Total Time'},
    'report.daily_average': {'zh-CN': '日均用时', 'en': 'Daily Average'},
    'report.session_detail': {'zh-CN': '时段明细', 'en': 'Session Details'},
    'report.device_detail': {'zh-CN': '设备明细', 'en': 'Device Breakdown'},
    'report.empty': {'zh-CN': '暂无数据', 'en': 'No data'},
    'report.start_date': {'zh-CN': '开始日期', 'en': 'Start Date'},
    'report.end_date': {'zh-CN': '结束日期', 'en': 'End Date'},
    'report.generate': {'zh-CN': '生成报告', 'en': 'Generate Report'},
    'report.date': {'zh-CN': '日期', 'en': 'Date'},
    'report.daily_breakdown': {'zh-CN': '每日明细', 'en': 'Daily Breakdown'},

    'settings.title': {'zh-CN': '设置', 'en': 'Settings'},
    'settings.language': {'zh-CN': '界面语言', 'en': 'Language'},
    'settings.language_system': {'zh-CN': '跟随系统', 'en': 'Follow System'},
    'settings.device_name': {'zh-CN': '设备名称', 'en': 'Device Name'},
    'settings.eye_rest': {'zh-CN': '用眼休息提醒', 'en': 'Eye Rest Reminder'},
    'settings.posture': {'zh-CN': '姿势切换提醒', 'en': 'Posture Change Reminder'},
    'settings.posture_interval': {'zh-CN': '姿势切换间隔', 'en': 'Posture Interval'},
    'settings.meeting_mode': {'zh-CN': '会议模式', 'en': 'Meeting Mode'},
    'settings.meeting_mode_desc': {'zh-CN': '开启后，休息提醒弹窗将显示关闭按钮', 'en': 'Show close button on break reminders'},
    'settings.overtime': {'zh-CN': '超时提醒', 'en': 'Overtime Reminder'},
    'settings.sync_path': {'zh-CN': '网盘同步路径', 'en': 'Sync Folder Path'},
    'settings.save': {'zh-CN': '保存', 'en': 'Save'},

    'tracking.title': {'zh-CN': 'LLM Ranking', 'en': 'LLM Ranking'},
    'tracking.refresh': {'zh-CN': '刷新数据', 'en': 'Refresh'},
    'tracking.fetching': {'zh-CN': '正在获取数据...', 'en': 'Fetching...'},
    'tracking.rank': {'zh-CN': '排名', 'en': 'Rank'},
    'tracking.model': {'zh-CN': '模型', 'en': 'Model'},
    'tracking.provider': {'zh-CN': '提供商', 'en': 'Provider'},
    'tracking.prompt_tokens': {'zh-CN': 'Prompt Tokens', 'en': 'Prompt Tokens'},
    'tracking.completion_tokens': {'zh-CN': 'Output Tokens', 'en': 'Output Tokens'},
    'tracking.weekly_revenue': {'zh-CN': 'Weekly Revenue', 'en': 'Weekly Revenue'},
    'tracking.source': {'zh-CN': '数据来源', 'en': 'Source'},

    'about.developer': {'zh-CN': '开发者：TimberTrail', 'en': 'Developer: TimberTrail'},
    'about.version': {'zh-CN': '版本：V$appVersion', 'en': 'Version: V$appVersion'},
    'about.license': {'zh-CN': '免费使用', 'en': 'Free to use'},
    'about.description': {'zh-CN': '跨平台屏幕用时管理工具，守护您的眼睛和健康', 'en': 'Cross-platform screen time manager'},

    'overtime.title': {'zh-CN': '屏幕用时已超计划', 'en': 'Screen Time Exceeded Plan'},
    'overtime.acknowledge': {'zh-CN': '我知道了', 'en': 'Got it'},
    'overtime.exceeded': {'zh-CN': '已超出', 'en': 'Exceeded by'},

    'weekly.title': {'zh-CN': '上周用时总结', 'en': 'Last Week Summary'},
    'weekly.confirm': {'zh-CN': '确认计划', 'en': 'Confirm Plan'},

    'stop_reason.eye_rest': {'zh-CN': '用眼休息', 'en': 'Eye Rest'},
    'stop_reason.posture_change': {'zh-CN': '姿势切换', 'en': 'Posture Change'},
    'stop_reason.lock_screen': {'zh-CN': '锁屏', 'en': 'Lock Screen'},
    'stop_reason.screensaver': {'zh-CN': '屏保', 'en': 'Screensaver'},
    'stop_reason.standby': {'zh-CN': '待机', 'en': 'Standby'},
    'stop_reason.shutdown': {'zh-CN': '关机', 'en': 'Shutdown'},
    'stop_reason.user_exit': {'zh-CN': '用户退出', 'en': 'User Exit'},
    'stop_reason.meeting_override': {'zh-CN': '会议模式关闭', 'en': 'Meeting Override'},
    'stop_reason.app_background': {'zh-CN': 'App 切到后台', 'en': 'App Background'},

    'common.ok': {'zh-CN': '确定', 'en': 'OK'},
    'common.cancel': {'zh-CN': '取消', 'en': 'Cancel'},
    'common.save': {'zh-CN': '保存', 'en': 'Save'},
    'common.close': {'zh-CN': '关闭', 'en': 'Close'},
    'common.enabled': {'zh-CN': '开启', 'en': 'On'},
    'common.disabled': {'zh-CN': '关闭', 'en': 'Off'},
  };

  static String t(String key, {Map<String, String>? vars}) {
    final entry = _strings[key];
    if (entry == null) return key;
    String text = entry[_lang] ?? entry['en'] ?? key;
    if (vars != null) {
      vars.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }

  static String translateStopReason(String reason) {
    return t('stop_reason.$reason');
  }

  static String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (_lang.startsWith('zh')) {
      if (h > 0 && m > 0) return '${h}小时${m}分钟';
      if (h > 0) return '${h}小时';
      if (m > 0) return '${m}分钟';
      return '不到1分钟';
    } else {
      if (h > 0 && m > 0) return '${h}h ${m}m';
      if (h > 0) return '${h}h';
      if (m > 0) return '${m}m';
      return '<1m';
    }
  }

  static String formatTokens(int? n) {
    if (n == null) return '-';
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
    return n.toString();
  }

  static String formatRevenue(int? n) {
    if (n == null) return '-';
    return '\$${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}
