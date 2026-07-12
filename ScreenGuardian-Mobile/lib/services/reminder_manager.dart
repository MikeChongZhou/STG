/// Reminder Manager - Eye Rest and Posture Change reminders
/// Loads settings from LocalStore for persistence

import 'dart:async';
import 'local_store.dart';

enum ReminderType { eyeRest, postureChange }

class ReminderEvent {
  final ReminderType type;
  final int countdownSeconds;
  final bool meetingMode;

  ReminderEvent({
    required this.type,
    required this.countdownSeconds,
    required this.meetingMode,
  });
}

class ReminderManager {
  final LocalStore _store;

  Timer? _eyeRestTimer;
  Timer? _postureTimer;
  bool _eyeRestActive = false;
  bool _postureActive = false;

  int _eyeRestIntervalMs;
  int _postureIntervalMs;
  bool _meetingMode;
  bool _eyeRestEnabled;
  bool _postureEnabled;

  final _controller = StreamController<ReminderEvent>.broadcast();
  Stream<ReminderEvent> get reminderStream => _controller.stream;

  ReminderManager({required LocalStore store})
      : _store = store,
        _eyeRestIntervalMs = 20 * 60 * 1000, // default 20 min
        _postureIntervalMs = store.config.postureIntervalMinutes * 60 * 1000,
        _meetingMode = store.config.meetingMode,
        _eyeRestEnabled = store.config.eyeRestEnabled,
        _postureEnabled = store.config.postureEnabled;

  /// Reload settings from store (call after settings change)
  void reloadSettings() {
    final config = _store.config;
    _postureIntervalMs = config.postureIntervalMinutes * 60 * 1000;
    _meetingMode = config.meetingMode;
    _eyeRestEnabled = config.eyeRestEnabled;
    _postureEnabled = config.postureEnabled;
    resetTimers();
  }

  void startTimers() {
    if (_eyeRestEnabled) _startEyeRestTimer();
    if (_postureEnabled) _startPostureTimer();
  }

  void stopTimers() {
    _eyeRestTimer?.cancel();
    _postureTimer?.cancel();
    _eyeRestActive = false;
    _postureActive = false;
  }

  void resetTimers() {
    stopTimers();
    startTimers();
  }

  void _startEyeRestTimer() {
    _eyeRestTimer?.cancel();
    _eyeRestTimer = Timer(Duration(milliseconds: _eyeRestIntervalMs), () {
      if (hasActiveReminder) return; // 另一个提醒正在显示，跳过这次
      _eyeRestActive = true;
      _controller.add(ReminderEvent(
        type: ReminderType.eyeRest,
        countdownSeconds: 20,
        meetingMode: _meetingMode,
      ));
    });
  }

  void _startPostureTimer() {
    _postureTimer?.cancel();
    _postureTimer = Timer(Duration(milliseconds: _postureIntervalMs), () {
      if (hasActiveReminder) return; // 另一个提醒正在显示，跳过这次
      _postureActive = true;
      _controller.add(ReminderEvent(
        type: ReminderType.postureChange,
        countdownSeconds: 120,
        meetingMode: _meetingMode,
      ));
    });
  }

  void onEyeRestDialogClosed() {
    _eyeRestActive = false;
    _startEyeRestTimer(); // 只重启眼部休息定时器
  }

  void onPostureDialogClosed() {
    _postureActive = false;
    _startPostureTimer(); // 只重启姿势定时器
  }

  bool get isEyeRestActive => _eyeRestActive;
  bool get isPostureActive => _postureActive;
  bool get hasActiveReminder => _eyeRestActive || _postureActive;

  int get eyeRestIntervalMs => _eyeRestIntervalMs;
  int get postureIntervalMs => _postureIntervalMs;
  bool get meetingMode => _meetingMode;
  bool get eyeRestEnabled => _eyeRestEnabled;
  bool get postureEnabled => _postureEnabled;

  void dispose() {
    stopTimers();
    _controller.close();
  }
}
