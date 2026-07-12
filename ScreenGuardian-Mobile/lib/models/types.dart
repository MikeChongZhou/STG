// ScreenGuardian - Core Type Definitions
// Mirrors the TypeScript types from the desktop app

enum PlatformType {
  windows,
  macos,
  androidPhone,
  androidPad,
  iphone,
  ipad,
}

enum StopReason {
  eyeRest,
  postureChange,
  lockScreen,
  screensaver,
  standby,
  shutdown,
  userExit,
  meetingOverride,
  appBackground,
}

enum ScreenState { active, locked, screensaver, sleep, shutdown }

enum Language { system, zhCN, en }

class ScreenSession {
  final String id;
  final String deviceId;
  final String deviceName;
  final PlatformType platform;
  final DateTime startTime;
  DateTime? endTime;
  int? durationSeconds;
  StopReason? stopReason;
  final String date; // YYYY-MM-DD
  final DateTime createdAt;
  DateTime updatedAt;
  int version;

  ScreenSession({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.stopReason,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  bool get isActive => endTime == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform.name,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'stopReason': stopReason?.name,
    'date': date,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
  };

  static PlatformType _parsePlatform(String? value) {
    if (value == null) return PlatformType.iphone;
    // Handle snake_case from desktop (android_phone → androidPhone)
    final normalized = value.contains('_')
        ? value.split('_').map((i) => i == value.split('_').first ? i : '${i[0].toUpperCase()}${i.substring(1)}').join()
        : value;
    return PlatformType.values.firstWhere(
      (e) => e.name == normalized || e.name == value,
      orElse: () => PlatformType.iphone,
    );
  }

  static StopReason _parseStopReason(String? value) {
    if (value == null) return StopReason.shutdown;
    final normalized = value.contains('_')
        ? value.split('_').map((i) => i == value.split('_').first ? i : '${i[0].toUpperCase()}${i.substring(1)}').join()
        : value;
    return StopReason.values.firstWhere(
      (e) => e.name == normalized || e.name == value,
      orElse: () => StopReason.shutdown,
    );
  }

  factory ScreenSession.fromJson(Map<String, dynamic> json) => ScreenSession(
    id: json['id'] ?? '',
    deviceId: json['deviceId'] ?? '',
    deviceName: json['deviceName'] ?? 'Unknown',
    platform: _parsePlatform(json['platform']),
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    durationSeconds: json['durationSeconds'],
    stopReason: _parseStopReason(json['stopReason']),
    date: json['date'] ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    version: json['version'] ?? 1,
  );
}

class DailySummary {
  final String date;
  int totalSeconds;
  int sessionCount;
  List<String> devices;
  String? firstSessionStart;
  String? lastSessionEnd;
  List<String> sessionIds;
  DateTime updatedAt;

  DailySummary({
    required this.date,
    this.totalSeconds = 0,
    this.sessionCount = 0,
    this.devices = const [],
    this.firstSessionStart,
    this.lastSessionEnd,
    this.sessionIds = const [],
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'totalSeconds': totalSeconds,
    'sessionCount': sessionCount,
    'devices': devices,
    'firstSessionStart': firstSessionStart,
    'lastSessionEnd': lastSessionEnd,
    'sessionIds': sessionIds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
    date: json['date'],
    totalSeconds: json['totalSeconds'] ?? 0,
    sessionCount: json['sessionCount'] ?? 0,
    devices: List<String>.from(json['devices'] ?? []),
    firstSessionStart: json['firstSessionStart'],
    lastSessionEnd: json['lastSessionEnd'],
    sessionIds: List<String>.from(json['sessionIds'] ?? []),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

class WeeklyPlan {
  final String weekStart; // YYYY-MM-DD (Monday)
  int plannedDailyMinutes;
  String source; // 'user_input' or 'auto_from_last_week'
  DateTime createdAt;

  WeeklyPlan({
    required this.weekStart,
    required this.plannedDailyMinutes,
    required this.source,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart,
    'plannedDailyMinutes': plannedDailyMinutes,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) => WeeklyPlan(
    weekStart: json['weekStart'],
    plannedDailyMinutes: json['plannedDailyMinutes'],
    source: json['source'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class DeviceInfo {
  String deviceId;
  String deviceName;
  final PlatformType platform;
  final DateTime registeredAt;
  DateTime? lastSyncAt;
  DateTime? lastActiveAt;
  String appVersion;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.registeredAt,
    this.lastSyncAt,
    this.lastActiveAt,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform.name,
    'registeredAt': registeredAt.toIso8601String(),
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'lastActiveAt': lastActiveAt?.toIso8601String(),
    'appVersion': appVersion,
  };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    deviceId: json['deviceId'] ?? '',
    deviceName: json['deviceName'] ?? 'Unknown',
    platform: ScreenSession._parsePlatform(json['platform']),
    registeredAt: json['registeredAt'] != null ? DateTime.parse(json['registeredAt']) : DateTime.now(),
    lastSyncAt: json['lastSyncAt'] != null ? DateTime.parse(json['lastSyncAt']) : null,
    lastActiveAt: json['lastActiveAt'] != null ? DateTime.parse(json['lastActiveAt']) : null,
    appVersion: json['appVersion'] ?? '1.0.0',
  );
}

class AppConfig {
  String language;
  int postureIntervalMinutes;
  List<String> trackingTargets;
  bool meetingMode;
  String? syncFolderPath;
  String? deviceName;
  bool eyeRestEnabled;
  bool postureEnabled;
  bool overtimeEnabled;
  DateTime updatedAt;
  String updatedBy;

  AppConfig({
    this.language = 'system',
    this.postureIntervalMinutes = 30,
    this.trackingTargets = const ['llm_ranking'],
    this.meetingMode = false,
    this.syncFolderPath,
    this.deviceName,
    this.eyeRestEnabled = true,
    this.postureEnabled = true,
    this.overtimeEnabled = true,
    required this.updatedAt,
    required this.updatedBy,
  });

  Map<String, dynamic> toJson() => {
    'language': language,
    'postureIntervalMinutes': postureIntervalMinutes,
    'trackingTargets': trackingTargets,
    'meetingMode': meetingMode,
    'syncFolderPath': syncFolderPath,
    'deviceName': deviceName,
    'eyeRestEnabled': eyeRestEnabled,
    'postureEnabled': postureEnabled,
    'overtimeEnabled': overtimeEnabled,
    'updatedAt': updatedAt.toIso8601String(),
    'updatedBy': updatedBy,
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    language: json['language'] ?? 'system',
    postureIntervalMinutes: json['postureIntervalMinutes'] ?? 30,
    trackingTargets: List<String>.from(json['trackingTargets'] ?? ['llm_ranking']),
    meetingMode: json['meetingMode'] ?? false,
    syncFolderPath: json['syncFolderPath'],
    deviceName: json['deviceName'],
    eyeRestEnabled: json['eyeRestEnabled'] ?? true,
    postureEnabled: json['postureEnabled'] ?? true,
    overtimeEnabled: json['overtimeEnabled'] ?? true,
    updatedAt: DateTime.parse(json['updatedAt']),
    updatedBy: json['updatedBy'],
  );
}

class RankingEntry {
  final int rank;
  final String modelId;
  final String modelName;
  final String provider;
  final int? promptTokens;
  final int? completionTokens;
  final double? inputPricePerMToken;
  final double? outputPricePerMToken;
  final int? weeklyRevenue;
  final int? requestCount;

  RankingEntry({
    required this.rank,
    required this.modelId,
    required this.modelName,
    required this.provider,
    this.promptTokens,
    this.completionTokens,
    this.inputPricePerMToken,
    this.outputPricePerMToken,
    this.weeklyRevenue,
    this.requestCount,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
    rank: json['rank'],
    modelId: json['modelId'],
    modelName: json['modelName'],
    provider: json['provider'],
    promptTokens: json['promptTokens'],
    completionTokens: json['completionTokens'],
    inputPricePerMToken: (json['inputPricePerMToken'] as num?)?.toDouble(),
    outputPricePerMToken: (json['outputPricePerMToken'] as num?)?.toDouble(),
    weeklyRevenue: json['weeklyRevenue'],
    requestCount: json['requestCount'],
  );
}

class LLMRankingRecord {
  final String weekStart;
  final String weekEnd;
  final DateTime fetchedAt;
  final String fetchedBy;
  final String source;
  final List<RankingEntry> data;

  LLMRankingRecord({
    required this.weekStart,
    required this.weekEnd,
    required this.fetchedAt,
    required this.fetchedBy,
    required this.source,
    required this.data,
  });

  factory LLMRankingRecord.fromJson(Map<String, dynamic> json) => LLMRankingRecord(
    weekStart: json['weekStart'],
    weekEnd: json['weekEnd'],
    fetchedAt: DateTime.parse(json['fetchedAt']),
    fetchedBy: json['fetchedBy'],
    source: json['source'],
    data: (json['data'] as List).map((e) => RankingEntry.fromJson(e)).toList(),
  );
}
