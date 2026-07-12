/// Time utilities for ScreenGuardian Mobile

String todayDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String formatDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String formatTime(DateTime d) {
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String getMonday(String dateStr) {
  final d = DateTime.parse('${dateStr}T00:00:00');
  final day = d.weekday; // 1=Mon, 7=Sun
  final diff = day - 1;
  final monday = d.subtract(Duration(days: diff));
  return formatDate(monday);
}

String addDays(String dateStr, int days) {
  final d = DateTime.parse('${dateStr}T00:00:00');
  return formatDate(d.add(Duration(days: days)));
}

String getDayOfWeek(String dateStr) {
  final d = DateTime.parse('${dateStr}T00:00:00');
  const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return days[d.weekday - 1];
}

int diffSeconds(DateTime start, DateTime end) {
  return (end.difference(start).inSeconds).clamp(0, double.infinity).toInt();
}

String getWeekString(String dateStr) {
  final monday = getMonday(dateStr);
  return '${monday.substring(0, 4)}-W${_weekOfYear(monday)}';
}

int _weekOfYear(String dateStr) {
  final d = DateTime.parse('${dateStr}T00:00:00');
  final firstDay = DateTime(d.year, 1, 1);
  final firstMonday = firstDay.add(Duration(days: (8 - firstDay.weekday) % 7));
  if (d.isBefore(firstMonday)) return 1;
  return ((d.difference(firstMonday).inDays) / 7).floor() + 1;
}
