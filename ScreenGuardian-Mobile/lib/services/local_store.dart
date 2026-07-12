/// Local Store - File-based JSON persistence layer
/// Data format matches ScreenGuardian Desktop for cross-platform sync

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/types.dart';
import '../utils/time_utils.dart';

class LocalStore {
  static LocalStore? _instance;
  late Directory _dataDir;
  late DeviceInfo _deviceInfo;
  late AppConfig _config;
  late AppState _state;

  LocalStore._();

  static Future<LocalStore> getInstance() async {
    if (_instance == null) {
      _instance = LocalStore._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = Directory(p.join(appDir.path, 'screenguardian'));
    if (!await _dataDir.exists()) {
      await _dataDir.create(recursive: true);
    }
    // Ensure subdirectories exist
    for (final subdir in ['sessions', 'summaries', 'plans', 'tracking/llm-ranking', 'devices']) {
      final dir = Directory(p.join(_dataDir.path, subdir));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    _loadOrCreateDeviceInfo();
    _loadOrCreateConfig();
    _loadOrCreateState();
    _performCrashRecovery();
  }

  String get dataPath => _dataDir.path;

  // ============================================================
  // File I/O helpers
  // ============================================================

  Future<Map<String, dynamic>?> _readJson(String relativePath) async {
    final file = File(p.join(_dataDir.path, relativePath));
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> _readJsonList(String relativePath) async {
    final file = File(p.join(_dataDir.path, relativePath));
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  Future<void> _writeJson(String relativePath, dynamic data) async {
    final file = File(p.join(_dataDir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  // ============================================================
  // Device Info
  // ============================================================

  void _loadOrCreateDeviceInfo() {
    final json = _readJsonSync('device.json');

    if (json != null) {
      _deviceInfo = DeviceInfo.fromJson(json);
    } else {
      final platform = _detectPlatform();
      final prefix = platform == PlatformType.iphone ? 'ios' : 'android';
      _deviceInfo = DeviceInfo(
        deviceId: 'dev-$prefix-${const Uuid().v4().substring(0, 8)}',
        deviceName: _defaultDeviceName(platform),
        platform: platform,
        registeredAt: DateTime.now(),
        appVersion: appVersion,
      );
      _writeJsonSync('device.json', _deviceInfo.toJson());
    }
    _deviceInfo.lastActiveAt = DateTime.now();
    _deviceInfo.appVersion = appVersion;
    _writeJsonSync('device.json', _deviceInfo.toJson());

    // Persist device ID to SharedPreferences (async, non-blocking)
    _persistDeviceId(_deviceInfo.deviceId);
  }

  Future<void> _persistDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persistedId = prefs.getString('sg_device_id');
      if (persistedId == null) {
        await prefs.setString('sg_device_id', deviceId);
      } else if (persistedId != deviceId) {
        // Use persisted ID (survives reinstalls)
        _deviceInfo.deviceId = persistedId;
        _writeJsonSync('device.json', _deviceInfo.toJson());
      }
    } catch (e) {
      print('[LocalStore] SharedPreferences not available: $e');
    }
  }

  static PlatformType _detectPlatform() {
    if (Platform.isAndroid) return PlatformType.androidPhone;
    if (Platform.isIOS) return PlatformType.iphone;
    return PlatformType.iphone;
  }

  static String _defaultDeviceName(PlatformType platform) {
    switch (platform) {
      case PlatformType.androidPhone:
        return 'Android Device';
      case PlatformType.iphone:
        return 'iOS Device';
      default:
        return 'Mobile Device';
    }
  }

  DeviceInfo get deviceInfo => _deviceInfo;
  String get deviceId => _deviceInfo.deviceId;
  String get deviceName => _config.deviceName ?? _deviceInfo.deviceName;

  // ============================================================
  // AppConfig
  // ============================================================

  void _loadOrCreateConfig() {
    final json = _readJsonSync('config.json');
    if (json != null) {
      _config = AppConfig.fromJson(json);
    } else {
      _config = AppConfig(
        updatedAt: DateTime.now(),
        updatedBy: deviceId,
      );
      _writeJsonSync('config.json', _config.toJson());
    }
  }

  AppConfig get config => _config;

  Future<AppConfig> updateConfig(Map<String, dynamic> patch) async {
    final json = _config.toJson();
    json.addAll(patch);
    json['updatedAt'] = DateTime.now().toIso8601String();
    json['updatedBy'] = deviceId;
    _config = AppConfig.fromJson(json);
    await _writeJson('config.json', _config.toJson());
    return _config;
  }

  // ============================================================
  // AppState
  // ============================================================

  void _loadOrCreateState() {
    final json = _readJsonSync('state.json');
    if (json != null) {
      _state = AppState.fromJson(json);
    } else {
      _state = AppState();
      _writeJsonSync('state.json', _state.toJson());
    }
  }

  AppState get state => _state;

  Future<void> updateState(Map<String, dynamic> patch) async {
    final json = _state.toJson();
    json.addAll(patch);
    _state = AppState.fromJson(json);
    await _writeJson('state.json', _state.toJson());
  }

  // ============================================================
  // Sessions
  // ============================================================

  String _monthKey(String date) => date.substring(0, 7);

  Future<List<ScreenSession>> loadSessions(String monthKey) async {
    final list = await _readJsonList('sessions/$monthKey.json');
    final sessions = <ScreenSession>[];
    for (final e in list) {
      try {
        sessions.add(ScreenSession.fromJson(e as Map<String, dynamic>));
      } catch (err) {
        print('[LocalStore] Skipping corrupted session: $err');
      }
    }
    return sessions;
  }

  List<ScreenSession> _loadSessionsSync(String monthKey) {
    final list = _readJsonListSync('sessions/$monthKey.json');
    return list.map((e) => ScreenSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ScreenSession> createSession({DateTime? startTime}) async {
    final now = startTime ?? DateTime.now();
    final session = ScreenSession(
      id: const Uuid().v4(),
      deviceId: deviceId,
      deviceName: deviceName,
      platform: _deviceInfo.platform,
      startTime: now,
      date: formatDate(now),
      createdAt: now,
      updatedAt: now,
    );
    final mk = _monthKey(session.date);
    final sessions = await loadSessions(mk);
    sessions.add(session);
    await _writeJson('sessions/$mk.json', sessions.map((s) => s.toJson()).toList());
    await updateState({'currentSessionId': session.id});
    return session;
  }

  Future<ScreenSession?> endSession(String sessionId, StopReason reason, {DateTime? endTime}) async {
    final now = endTime ?? DateTime.now();
    final mk = _monthKey(formatDate(now));
    final sessions = await loadSessions(mk);

    var session = sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) {
      // Try previous month
      final prevDate = DateTime(now.year, now.month - 1, 1);
      final prevMk = _monthKey(formatDate(prevDate));
      final prevSessions = await loadSessions(prevMk);
      session = prevSessions.where((s) => s.id == sessionId).firstOrNull;
      if (session != null) {
        return _endSessionInList(prevSessions, prevMk, sessionId, reason, now);
      }
      return null;
    }
    return _endSessionInList(sessions, mk, sessionId, reason, now);
  }

  Future<ScreenSession?> _endSessionInList(
    List<ScreenSession> sessions,
    String monthKey,
    String sessionId,
    StopReason reason,
    DateTime endTime,
  ) async {
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return null;

    final session = sessions[index];
    session.endTime = endTime;
    session.durationSeconds = endTime.difference(session.startTime).inSeconds.clamp(0, 999999);
    session.stopReason = reason;
    session.updatedAt = DateTime.now();
    session.version++;

    await _writeJson('sessions/$monthKey.json', sessions.map((s) => s.toJson()).toList());
    await updateDailySummary(session.date);
    await updateState({'currentSessionId': null});
    return session;
  }

  Future<int> getTodayTotalSeconds() async {
    final today = todayDate();
    final mk = _monthKey(today);
    final sessions = await loadSessions(mk);
    int total = 0;
    for (final s in sessions) {
      if (s.date == today && s.durationSeconds != null) {
        total += s.durationSeconds!;
      }
    }
    // Add current session elapsed
    if (_state.currentSessionId != null) {
      final current = sessions.where((s) => s.id == _state.currentSessionId).firstOrNull;
      if (current != null && current.date == today) {
        total += DateTime.now().difference(current.startTime).inSeconds.clamp(0, 999999);
      }
    }
    return total;
  }

  // ============================================================
  // DailySummary
  // ============================================================

  Future<List<DailySummary>> loadSummaries(String monthKey) async {
    final list = await _readJsonList('summaries/$monthKey.json');
    return list.map((e) => DailySummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DailySummary> updateDailySummary(String date) async {
    final mk = _monthKey(date);
    final sessions = await loadSessions(mk);
    final daySessions = sessions.where((s) => s.date == date && s.endTime != null).toList();
    final summaries = await loadSummaries(mk);

    final totalSeconds = daySessions.fold(0, (sum, s) => sum + (s.durationSeconds ?? 0));
    final devices = daySessions.map((s) => s.deviceId).toSet().toList();
    final sessionIds = daySessions.map((s) => s.id).toList();
    final startTimes = daySessions.map((s) => s.startTime).toList()..sort();
    final endTimes = daySessions.where((s) => s.endTime != null).map((s) => s.endTime!).toList()..sort();

    final newSummary = DailySummary(
      date: date,
      totalSeconds: totalSeconds,
      sessionCount: daySessions.length,
      devices: devices,
      firstSessionStart: startTimes.isNotEmpty ? startTimes.first.toIso8601String() : null,
      lastSessionEnd: endTimes.isNotEmpty ? endTimes.last.toIso8601String() : null,
      sessionIds: sessionIds,
      updatedAt: DateTime.now(),
    );

    final existingIndex = summaries.indexWhere((s) => s.date == date);
    if (existingIndex >= 0) {
      summaries[existingIndex] = newSummary;
    } else {
      summaries.add(newSummary);
    }
    await _writeJson('summaries/$mk.json', summaries.map((s) => s.toJson()).toList());
    return newSummary;
  }

  Future<DailySummary?> getDailySummary(String date) async {
    final mk = _monthKey(date);
    final summaries = await loadSummaries(mk);
    return summaries.where((s) => s.date == date).firstOrNull;
  }

  // ============================================================
  // Query helpers for reports
  // ============================================================

  Future<List<ScreenSession>> querySessions({
    required String startDate,
    required String endDate,
    String? deviceId,
    StopReason? stopReason,
  }) async {
    final startMonth = startDate.substring(0, 7);
    final endMonth = endDate.substring(0, 7);
    final months = _getMonthRange(startMonth, endMonth);
    final results = <ScreenSession>[];

    for (final mk in months) {
      final sessions = await loadSessions(mk);
      for (final s in sessions) {
        if (s.date.compareTo(startDate) < 0 || s.date.compareTo(endDate) > 0) continue;
        if (deviceId != null && s.deviceId != deviceId) continue;
        if (stopReason != null && s.stopReason != stopReason) continue;
        results.add(s);
      }
    }
    results.sort((a, b) => a.startTime.compareTo(b.startTime));
    return results;
  }

  Future<List<DailySummary>> querySummaries({
    required String startDate,
    required String endDate,
  }) async {
    final startMonth = startDate.substring(0, 7);
    final endMonth = endDate.substring(0, 7);
    final months = _getMonthRange(startMonth, endMonth);
    final results = <DailySummary>[];

    for (final mk in months) {
      final summaries = await loadSummaries(mk);
      for (final s in summaries) {
        if (s.date.compareTo(startDate) >= 0 && s.date.compareTo(endDate) <= 0) {
          results.add(s);
        }
      }
    }
    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  List<String> _getMonthRange(String startMonth, String endMonth) {
    final months = <String>[];
    var current = startMonth;
    while (current.compareTo(endMonth) <= 0) {
      months.add(current);
      final parts = current.split('-').map(int.parse).toList();
      final nextMonth = parts[1] == 12 ? 1 : parts[1] + 1;
      final nextYear = parts[1] == 12 ? parts[0] + 1 : parts[0];
      current = '${nextYear}-${nextMonth.toString().padLeft(2, '0')}';
    }
    return months;
  }

  // ============================================================
  // Crash Recovery
  // ============================================================

  Future<void> _performCrashRecovery() async {
    if (_state.currentSessionId != null) {
      final session = await endSession(_state.currentSessionId!, StopReason.shutdown);
      if (session != null) {
        print('[CrashRecovery] Closed orphaned session ${session.id}, duration: ${session.durationSeconds}s');
      }
      await updateState({'currentSessionId': null});
    }
  }

  // ============================================================
  // Weekly Plans
  // ============================================================

  Future<List<WeeklyPlan>> loadWeeklyPlans() async {
    final list = await _readJsonList('plans/weekly.json');
    return list.map((e) => WeeklyPlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveWeeklyPlan(WeeklyPlan plan) async {
    final plans = await loadWeeklyPlans();
    final index = plans.indexWhere((p) => p.weekStart == plan.weekStart);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.add(plan);
    }
    await _writeJson('plans/weekly.json', plans.map((p) => p.toJson()).toList());
  }

  Future<WeeklyPlan?> getWeeklyPlan(String weekStart) async {
    final plans = await loadWeeklyPlans();
    return plans.where((p) => p.weekStart == weekStart).firstOrNull;
  }

  // ============================================================
  // Sync helpers (expose raw read/write for SyncService)
  // ============================================================

  Future<Map<String, dynamic>?> readRawJson(String relativePath) => _readJson(relativePath);
  Future<void> writeRawJson(String relativePath, dynamic data) => _writeJson(relativePath, data);

  // ============================================================
  // Synchronous helpers (for init-time use only)
  // ============================================================

  Map<String, dynamic>? _readJsonSync(String relativePath) {
    try {
      final file = File(p.join(_dataDir.path, relativePath));
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  List<dynamic> _readJsonListSync(String relativePath) {
    try {
      final file = File(p.join(_dataDir.path, relativePath));
      if (!file.existsSync()) return [];
      final content = file.readAsStringSync();
      return jsonDecode(content) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  void _writeJsonSync(String relativePath, dynamic data) {
    try {
      final file = File(p.join(_dataDir.path, relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      print('[LocalStore] Sync write error: $e');
    }
  }
}

/// App state - tracks current session, timer state, etc.
class AppState {
  String? currentSessionId;
  int? eyeRestTimerRemainingMs;
  int? postureTimerRemainingMs;
  String lastScreenState;
  bool meetingMode;
  String? lastWeeklySummaryWeek;
  bool overtimeAlertedToday;
  String? lastOvertimeReminderAt;

  AppState({
    this.currentSessionId,
    this.eyeRestTimerRemainingMs,
    this.postureTimerRemainingMs,
    this.lastScreenState = 'active',
    this.meetingMode = false,
    this.lastWeeklySummaryWeek,
    this.overtimeAlertedToday = false,
    this.lastOvertimeReminderAt,
  });

  Map<String, dynamic> toJson() => {
    'currentSessionId': currentSessionId,
    'eyeRestTimerRemainingMs': eyeRestTimerRemainingMs,
    'postureTimerRemainingMs': postureTimerRemainingMs,
    'lastScreenState': lastScreenState,
    'meetingMode': meetingMode,
    'lastWeeklySummaryWeek': lastWeeklySummaryWeek,
    'overtimeAlertedToday': overtimeAlertedToday,
    'lastOvertimeReminderAt': lastOvertimeReminderAt,
  };

  factory AppState.fromJson(Map<String, dynamic> json) => AppState(
    currentSessionId: json['currentSessionId'],
    eyeRestTimerRemainingMs: json['eyeRestTimerRemainingMs'],
    postureTimerRemainingMs: json['postureTimerRemainingMs'],
    lastScreenState: json['lastScreenState'] ?? 'active',
    meetingMode: json['meetingMode'] ?? false,
    lastWeeklySummaryWeek: json['lastWeeklySummaryWeek'],
    overtimeAlertedToday: json['overtimeAlertedToday'] ?? false,
    lastOvertimeReminderAt: json['lastOvertimeReminderAt'],
  );
}
