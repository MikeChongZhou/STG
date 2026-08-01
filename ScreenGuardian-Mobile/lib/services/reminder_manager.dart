/// Reminder Manager - Unified eye rest + posture change reminders
///
/// Design:
///   - Eye rest timer: fires every 20 minutes (configurable)
///   - Posture change: fires every 40 minutes (= 2× eye rest interval)
///   - When posture fires, show a COMBINED dialog: change posture + look 20ft away
///   - No separate posture timer — it piggybacks on the eye rest cycle

import 'dart:async';
import 'local_store.dart';

enum ReminderType {
  eyeRest,            // 20 min: just eye rest
  eyeRestAndPosture,  // 40 min: posture change + eye rest combined
}

class ReminderEvent {
  final ReminderType type;
  final int countdownSeconds;
  final bool meetingMode;

  ReminderEvent({
    required this.type,
    required this.countdownSeconds,
    required this.meetingMode,
  });

  bool get isCombined => type == ReminderType.eyeRestAndPosture;
}

class ReminderManager {
  final LocalStore _store;

  Timer? _timer;
  bool _active = false;
  int _triggerCount = 0; // counts eye rest triggers, every 2nd = posture

  int _eyeRestIntervalMs;
  bool _meetingMode;
  bool _eyeRestEnabled;
  bool _postureEnabled;

  final _controller = StreamController<ReminderEvent>.broadcast();
  Stream<ReminderEvent> get reminderStream => _controller.stream;

  ReminderManager({required LocalStore store})
      : _store = store,
        _eyeRestIntervalMs = 20 * 60 * 1000, // default 20 min
        _meetingMode = store.config.meetingMode,
        _eyeRestEnabled = store.config.eyeRestEnabled,
        _postureEnabled = store.config.postureEnabled;

  /// Reload settings from store (call after settings change)
  void reloadSettings() {
    final config = _store.config;
    _meetingMode = config.meetingMode;
    _eyeRestEnabled = config.eyeRestEnabled;
    _postureEnabled = config.postureEnabled;
    resetTimer();
  }

  void startTimers() {
    if (_eyeRestEnabled) _startTimer();
  }

  void stopTimers() {
    _timer?.cancel();
    _timer = null;
    _active = false;
  }

  void resetTimer() {
    stopTimers();
    startTimers();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: _eyeRestIntervalMs), () {
      if (_active) return;
      _active = true;
      _triggerCount++;

      // Every 2nd trigger → combined posture + eye rest
      final isPostureCycle = _postureEnabled && (_triggerCount % 2 == 0);

      _controller.add(ReminderEvent(
        type: isPostureCycle ? ReminderType.eyeRestAndPosture : ReminderType.eyeRest,
        countdownSeconds: isPostureCycle ? 120 : 20, // posture: 2min, eye rest: 20s
        meetingMode: _meetingMode,
      ));
    });
  }

  void onDialogClosed() {
    _active = false;
    _startTimer();
  }

  // Legacy compatibility
  void onEyeRestDialogClosed() => onDialogClosed();
  void onPostureDialogClosed() => onDialogClosed();

  bool get isActive => _active;
  bool get isEyeRestActive => _active;
  bool get isPostureActive => false; // no separate posture state
  bool get hasActiveReminder => _active;

  int get eyeRestIntervalMs => _eyeRestIntervalMs;
  int get postureIntervalMs => _eyeRestIntervalMs * 2; // derived
  bool get meetingMode => _meetingMode;
  bool get eyeRestEnabled => _eyeRestEnabled;
  bool get postureEnabled => _postureEnabled;

  void dispose() {
    stopTimers();
    _controller.close();
  }
}
