/// Session Manager - Core screen time recording engine for Mobile
/// Now uses LocalStore for persistent storage + cross-platform sync

import 'dart:async';
import '../models/types.dart';
import 'local_store.dart';

class SessionManager {
  final LocalStore _store;
  ScreenSession? _currentSession;
  DateTime? _currentSessionStart;

  final _sessionController = StreamController<SessionEvent>.broadcast();
  Stream<SessionEvent> get sessionStream => _sessionController.stream;

  SessionManager({required LocalStore store}) : _store = store;

  /// Initialize - recover from crash if needed
  Future<void> init() async {
    // Crash recovery is handled by LocalStore._init
    // Check if there's an active session we need to resume
    final state = _store.state;
    if (state.currentSessionId != null) {
      // Session was left open - it was already closed by crash recovery
      print('[SessionManager] Recovered from crash, session was closed');
    }
  }

  /// Start a new screen session
  Future<ScreenSession> startNewSession() async {
    final session = await _store.createSession();
    _currentSession = session;
    _currentSessionStart = session.startTime;
    _sessionController.add(SessionEvent(type: SessionEventType.started, session: session));
    return session;
  }

  /// Pause/end the current session
  Future<ScreenSession?> pauseCurrentSession(StopReason reason) async {
    if (_currentSession == null) return null;

    final now = DateTime.now();
    final elapsed = now.difference(_currentSessionStart!).inSeconds;

    // Discard sessions shorter than 60 seconds
    if (elapsed < 60) {
      _currentSession = null;
      _currentSessionStart = null;
      return null;
    }

    final session = await _store.endSession(_currentSession!.id, reason, endTime: now);
    if (session != null) {
      _sessionController.add(SessionEvent(type: SessionEventType.ended, session: session));
    }

    _currentSession = null;
    _currentSessionStart = null;
    return session;
  }

  /// Get current session elapsed seconds
  int getCurrentElapsedSeconds() {
    if (_currentSession == null || _currentSessionStart == null) return 0;
    return DateTime.now().difference(_currentSessionStart!).inSeconds;
  }

  /// Get today's total screen time in seconds
  Future<int> getTodayTotalSeconds() async {
    return await _store.getTodayTotalSeconds();
  }

  /// Check if there's an active session
  bool get hasActiveSession => _currentSession != null;

  /// Get current session
  ScreenSession? get currentSession => _currentSession;

  void dispose() {
    _sessionController.close();
  }
}

enum SessionEventType { started, ended, paused }

class SessionEvent {
  final SessionEventType type;
  final ScreenSession session;

  SessionEvent({required this.type, required this.session});
}
