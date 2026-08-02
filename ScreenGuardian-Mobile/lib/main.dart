/// ScreenGuardian Mobile - Main App Entry Point
/// Wires up persistence, sync, session tracking, and reminders

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import 'models/types.dart';
import 'services/local_store.dart';
import 'services/session_manager.dart';
import 'services/reminder_manager.dart';
import 'services/p2p_sync_service.dart';
import 'services/screentime_service.dart';
import 'screens/home_screen.dart';
import 'dialogs/overtime_alert_dialog.dart';
import 'dialogs/combined_reminder_dialog.dart';
import 'utils/i18n.dart';
import 'utils/time_utils.dart';

void main() {
  runApp(const ScreenGuardianApp());
}

class ScreenGuardianApp extends StatelessWidget {
  const ScreenGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenGuardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A237E),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  LocalStore? _store;
  SessionManager? _sessionManager;
  ReminderManager? _reminderManager;
  P2PSyncService? _p2pSync;

  static const _platform = MethodChannel('com.timbertrail.screenguardian/foreground');
  static const _screenChannel = MethodChannel('com.timbertrail.screenguardian/screen');

  int _currentElapsed = 0;
  int _todayTotal = 0;
  Timer? _uiTimer;
  bool _initialized = false;
  bool _isScreenOn = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  Future<void> _initApp() async {
    // Initialize store (loads persisted data, performs crash recovery)
    final store = await LocalStore.getInstance();

    // Apply saved language
    final config = store.config;
    if (config.language != 'system') {
      AppStrings.setLanguage(config.language);
    } else {
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      AppStrings.setLanguage(locale.languageCode == 'zh' ? 'zh-CN' : 'en');
    }

    // Initialize session manager
    final sessionManager = SessionManager(store: store);
    await sessionManager.init();

    // Initialize reminder manager
    final reminderManager = ReminderManager(store: store);

    // Initialize P2P sync service (WiFi LAN)
    final p2pSync = P2PSyncService(store);
    // Don't auto-start - user must pair first via settings

    // Listen for reminder events (Android only — iOS uses ScreenTime Shield overlays)
    if (Platform.isAndroid) {
      reminderManager.reminderStream.listen((event) {
        if (event.type == ReminderType.eyeRest || event.type == ReminderType.eyeRestAndPosture) {
          _handleReminderEvent(event);
        }
      });
    }

    // Listen for screen off/on events from Android BroadcastReceiver
    if (Platform.isAndroid) {
      _screenChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onScreenOff':
            // Screen turned off — pause session and stop timers
            _isScreenOn = false;
            _sessionManager?.pauseCurrentSession(StopReason.lockScreen);
            _reminderManager?.stopTimers();
            break;
          case 'onScreenOn':
            _isScreenOn = true;
            // Screen turned on — but not unlocked yet, wait for USER_PRESENT
            break;
          case 'onUserPresent':
            // Screen unlocked — start new session and timers
            if (_sessionManager != null && !_sessionManager!.hasActiveSession) {
              _sessionManager!.startNewSession();
              _reminderManager?.startTimers();
            }
            break;
        }
      });

      // Also check current screen state on startup
      try {
        final screenOn = await _screenChannel.invokeMethod('isScreenOn');
        if (screenOn != true) {
          // Screen is off at startup, don't start session
        }
      } catch (e) {
        // ignore
      }
    }

    // Start session (app is active)
    await sessionManager.startNewSession();
    reminderManager.startTimers();

    // Start foreground service on Android to keep running in background
    if (Platform.isAndroid) {
      try {
        await _platform.invokeMethod('startForegroundService');

        // Request basic permissions
        await _requestAndroidPermissions();

        // Check full-screen intent permission
        final hasPermission = await _platform.invokeMethod('hasFullScreenPermission');
        if (hasPermission != true && mounted) {
          _askFullScreenPermission();
        }
      } catch (e) {
        print('[Main] Failed to start foreground service: $e');
      }
    }

    // Start ScreenTime monitoring on iOS
    if (Platform.isIOS) {
      try {
        final authStatus = await ScreenTimeService.getAuthorizationStatus();
        if (authStatus == 'approved') {
          await ScreenTimeService.startMonitoring();
          _iosScreenTimeActive = true;
          print('[Main] ScreenTime monitoring started');
          // Don't start Flutter reminder timers — the extension handles reminders via Shield
        } else if (authStatus == 'notDetermined') {
          // Will ask on first visit to settings
          print('[Main] ScreenTime not yet authorized');
        } else {
          print('[Main] ScreenTime authorization denied');
        }
      } catch (e) {
        print('[Main] ScreenTime setup failed: $e');
      }
    }

    // Listen for notification tap + overlay callbacks (both platforms)
    _platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onReminderFromNotification':
          final type = call.arguments['type'] as String?;
          final fromBg = call.arguments['fromBackground'] as bool? ?? false;
          if (Platform.isIOS && fromBg) {
            _onReminderCountdownEnded();
            _reminderManager?.startTimers();
          } else if (type == 'combined') {
            _showReminderOverlay(ReminderEvent(
              type: ReminderType.eyeRestAndPosture,
              countdownSeconds: 120,
              meetingMode: store.config.meetingMode,
            ));
          } else if (type == 'eye_rest') {
            _showReminderOverlay(ReminderEvent(
              type: ReminderType.eyeRest,
              countdownSeconds: 20,
              meetingMode: store.config.meetingMode,
            ));
          }
          break;
        case 'onReminderCountdownEnded':
          // Overlay countdown finished → record data + restart screen timer
          _onReminderCountdownEnded();
          break;
        case 'onReminderOverlayClosed':
          // Overlay dismissed (user clicked close or screen off)
          _onReminderOverlayClosed();
          break;
      }
    });

    // Check for weekly summary (Monday)
    _checkWeeklySummary(store);

    // Check overtime
    _checkOvertime(store, sessionManager);

    // UI update timer
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final elapsed = sessionManager.getCurrentElapsedSeconds();
      final total = await sessionManager.getTodayTotalSeconds();
      if (mounted) {
        setState(() {
          _currentElapsed = elapsed;
          _todayTotal = total;
        });
      }
    });

    setState(() {
      _store = store;
      _sessionManager = sessionManager;
      _reminderManager = reminderManager;
      _p2pSync = p2pSync;
      _initialized = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _overtimeTimer?.cancel();
    _reminderManager?.dispose();
    _sessionManager?.dispose();
    _p2pSync?.stop();
    super.dispose();
  }

  bool _isAppInForeground = true;
  bool _iosScreenTimeActive = false; // true if ScreenTime monitoring is active on iOS

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_sessionManager == null || _reminderManager == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (Platform.isIOS) {
          if (!_iosScreenTimeActive) {
            // ScreenTime not available — legacy mode with background reminders
            _platform.invokeMethod('cancelBackgroundReminder');
          }
          // Clear any Shield overlays when user returns to app
          if (_iosScreenTimeActive) {
            ScreenTimeService.clearShields();
          }
        }
        if (!_sessionManager!.hasActiveSession) {
          _sessionManager!.startNewSession();
          if (!_iosScreenTimeActive) {
            _reminderManager!.startTimers(); // Only use Flutter timers if ScreenTime not active
          }
          _p2pSync?.syncWithAll();
        }
        break;
      case AppLifecycleState.paused:
        _isAppInForeground = false;
        if (Platform.isIOS) {
          _sessionManager!.pauseCurrentSession(StopReason.appBackground);
          if (!_iosScreenTimeActive) {
            // Legacy mode: schedule background notification for reminders
            final intervalMs = _reminderManager!.eyeRestIntervalMs;
            _platform.invokeMethod('scheduleBackgroundReminder', {
              'intervalSeconds': intervalMs ~/ 1000,
            });
            _reminderManager!.stopTimers();
          }
          // With ScreenTime: extension handles reminders via Shield, no action needed
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.detached:
        _sessionManager!.pauseCurrentSession(StopReason.userExit);
        break;
    }
  }

  // ============================================================
  // Reminder handling — overlay-based (works in foreground + background)
  // ============================================================

  Future<bool> _isInCallOrMeeting() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _platform.invokeMethod('isInCall');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  void _handleReminderEvent(ReminderEvent event) async {
    if (await _isInCallOrMeeting()) {
      final reason = event.isCombined ? StopReason.postureChange : StopReason.eyeRest;
      _sessionManager?.pauseCurrentSession(reason);
      _sessionManager?.startNewSession();
      _reminderManager?.onDialogClosed();
      return;
    }
    _showReminderOverlay(event);
  }

  // ── Flutter-side countdown timer (iOS only) ──
  Timer? _reminderCountdownTimer;

  /// Show reminder — platform-specific UI, unified data logic
  ///
  /// Flow:
  ///   1. Show platform UI immediately
  ///   2. Start countdown (Android: native / iOS: Flutter timer)
  ///   3. Countdown ends → record data + restart screen timer + show close button
  ///   4. User closes → clean up reminder state
  void _showReminderOverlay(ReminderEvent event) {
    final type = event.isCombined ? 'combined' : (event.type == ReminderType.eyeRest ? 'eye_rest' : 'posture_change');

    // ── Step 1: Show platform UI ──
    if (Platform.isAndroid) {
      // Android: native overlay with its own CountDownTimer
      // On countdown end → calls onReminderCountdownEnded back to Flutter
      _platform.invokeMethod('showReminderOverlay', {
        'type': type,
        'countdownSeconds': event.countdownSeconds,
        'meetingMode': event.meetingMode,
      });
      return; // Android handles everything natively
    }

    // ── iOS ──
    if (_isAppInForeground) {
      _showIOSDialog(event);
    } else {
      _platform.invokeMethod('showReminderOverlay', {
        'type': type,
        'countdownSeconds': event.countdownSeconds,
        'meetingMode': event.meetingMode,
      });
    }

    // ── Step 2: Start Flutter countdown (iOS only) ──
    _reminderCountdownTimer?.cancel();
    _reminderCountdownTimer = Timer(
      Duration(seconds: event.countdownSeconds),
      () {
        // ── Step 3: Countdown ended → record data + restart screen timer ──
        _onReminderCountdownEnded();
        // iOS dialog picks up _reminderCountdownTimer == null to show close button
      },
    );
  }

  /// iOS foreground dialog
  void _showIOSDialog(ReminderEvent event) {
    if (_sessionManager == null || _reminderManager == null) return;

    if (event.isCombined) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CombinedReminderDialog(
            countdownSeconds: event.countdownSeconds,
            meetingMode: event.meetingMode,
            onClosed: () {
              _onReminderOverlayClosed();
            },
          ),
        ),
      );
      _reminderCountdownTimer?.cancel();
      _reminderCountdownTimer = Timer(
        Duration(seconds: event.countdownSeconds),
        () => _onReminderCountdownEnded(),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _IOSReminderDialog(
          event: event,
          getTimer: () => _reminderCountdownTimer,
          onClosed: () {
            _onReminderOverlayClosed();
          },
        ),
      ),
    );
  }

  /// Countdown ended (all platforms) → record data + restart screen timer
  void _onReminderCountdownEnded() {
    if (_sessionManager == null || _reminderManager == null) return;

    final reason = _reminderManager!.isActive
        ? StopReason.eyeRest
        : StopReason.postureChange;
    _sessionManager!.pauseCurrentSession(reason);
    _sessionManager!.startNewSession();
  }

  /// UI closed (all platforms) → clean up reminder state
  void _onReminderOverlayClosed() {
    if (_reminderManager == null || _sessionManager == null) return;

    _reminderCountdownTimer?.cancel();
    _reminderCountdownTimer = null;

    _reminderManager!.onDialogClosed();

    if (_isScreenOn && !_sessionManager!.hasActiveSession) {
      // Don't start a new session if _onReminderCountdownEnded already did
      // (happens on iOS when dialog auto-closes after countdown)
      _sessionManager!.startNewSession();
    }
  }

  // ============================================================
  // Android permissions
  // ============================================================

  Future<void> _requestAndroidPermissions() async {
    // Request notification permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    // Request phone state permission (for call detection)
    final phoneStatus = await Permission.phone.status;
    if (!phoneStatus.isGranted) {
      await Permission.phone.request();
    }

    // Check usage stats (cannot request via dialog, guide user to settings)
    final usageStatus = await Permission.systemAlertWindow.status;
    if (!usageStatus.isGranted && mounted) {
      // Show a gentle hint, not blocking
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.lang.startsWith('zh')
                ? '💡 开启"使用情况访问"权限，可在微信/Zoom视频通话时自动跳过提醒'
                : '💡 Enable "Usage access" to skip reminders during WeChat/Zoom calls',
          ),
          action: SnackBarAction(
            label: AppStrings.lang.startsWith('zh') ? '去开启' : 'Enable',
            onPressed: () => openAppSettings(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ============================================================
  // Full-screen permission dialog
  // ============================================================

  void _askFullScreenPermission() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.lang.startsWith('zh') ? '🔔 提醒权限' : '🔔 Reminder Permission'),
        content: Text(
          AppStrings.lang.startsWith('zh')
              ? 'ScreenGuardian 需要"全屏提醒"权限，在屏幕用时达到提醒时间时自动弹出提醒窗口（类似来电显示）。\n\n如果不允许，提醒将以通知栏形式显示，需要手动点击才能打开。'
              : 'ScreenGuardian needs "full-screen reminder" permission to automatically show reminders when screen time reaches limits (like incoming calls).\n\nWithout it, reminders will show as notifications that you need to tap to open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.lang.startsWith('zh') ? '暂不开启' : 'Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _platform.invokeMethod('requestFullScreenPermission');
            },
            child: Text(AppStrings.lang.startsWith('zh') ? '去开启' : 'Enable'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Weekly Summary
  // ============================================================

  Future<void> _checkWeeklySummary(LocalStore store) async {
    final today = todayDate();
    final d = DateTime.parse('${today}T00:00:00');
    if (d.weekday != 1) return; // Only on Monday

    final currentWeekStart = getMonday(today);
    final state = store.state;

    // Check if already triggered this week
    if (state.lastWeeklySummaryWeek == getWeekString(today)) return;

    // Get last week's data
    final lastWeekStart = addDays(currentWeekStart, -7);
    final lastWeekEnd = addDays(currentWeekStart, -1);

    final summaries = await store.querySummaries(startDate: lastWeekStart, endDate: lastWeekEnd);
    int totalSeconds = 0;
    for (final s in summaries) {
      totalSeconds += s.totalSeconds;
    }
    final avgSeconds = summaries.isNotEmpty ? totalSeconds ~/ summaries.length : 0;

    // Update state
    await store.updateState({'lastWeeklySummaryWeek': getWeekString(today)});

    if (!mounted) return;

    // Show summary dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Text('📊', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text(AppStrings.lang.startsWith('zh') ? '上周用时总结' : 'Last Week Summary'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppStrings.lang.startsWith('zh') ? '上周' : 'Last week'}: $lastWeekStart ~ $lastWeekEnd'),
            const SizedBox(height: 12),
            Text('⏱️ ${AppStrings.lang.startsWith('zh') ? '总用时' : 'Total'}: ${AppStrings.formatDuration(totalSeconds)}'),
            Text('📊 ${AppStrings.lang.startsWith('zh') ? '日均' : 'Daily avg'}: ${AppStrings.formatDuration(avgSeconds)}'),
            const SizedBox(height: 12),
            Text(
              AppStrings.lang.startsWith('zh') ? '💡 建议本周保持健康用屏习惯' : '💡 Keep healthy screen habits this week',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('common.ok')),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Overtime Reminder
  // ============================================================

  Timer? _overtimeTimer;
  bool _overtimeAlertedToday = false;
  DateTime? _lastOvertimeReminder;

  void _checkOvertime(LocalStore store, SessionManager sessionManager) {
    // Check every 5 minutes
    _overtimeTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final config = store.config;
      if (!config.overtimeEnabled) return;

      // Get current week plan
      final today = todayDate();
      final monday = getMonday(today);
      final plan = await store.getWeeklyPlan(monday);
      if (plan == null) return; // No plan, no overtime check

      final todayTotal = await sessionManager.getTodayTotalSeconds();
      final plannedSeconds = plan.plannedDailyMinutes * 60;

      if (todayTotal <= plannedSeconds) return; // Not overtime

      if (!_overtimeAlertedToday) {
        _overtimeAlertedToday = true;
        _showOvertimeAlert(todayTotal, plannedSeconds, isFirst: true);
        _lastOvertimeReminder = DateTime.now();
      } else if (_lastOvertimeReminder != null) {
        final minutesSince = DateTime.now().difference(_lastOvertimeReminder!).inMinutes;
        if (minutesSince >= 25) {
          _lastOvertimeReminder = DateTime.now();
          _showOvertimeAlert(todayTotal, plannedSeconds, isFirst: false);
        }
      }
    });

    // Reset overtime flag at midnight
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    Timer(tomorrow.difference(now), () {
      _overtimeAlertedToday = false;
      _lastOvertimeReminder = null;
    });
  }

  void _showOvertimeAlert(int totalSeconds, int plannedSeconds, {required bool isFirst}) {
    if (!mounted) return;
    OvertimeAlertDialog.show(
      context,
      totalSeconds: totalSeconds,
      plannedSeconds: plannedSeconds,
      isFirst: isFirst,
      onContinue: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🛡️', style: TextStyle(fontSize: 64)),
              SizedBox(height: 16),
              Text('ScreenGuardian', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return HomeScreen(
      currentElapsedSeconds: _currentElapsed,
      todayTotalSeconds: _todayTotal,
      p2pSync: _p2pSync,
      reminderManager: _reminderManager,
      onBeforeReport: () {
        // Pause current session so report includes it, then restart
        if (_sessionManager?.hasActiveSession == true) {
          _sessionManager!.pauseCurrentSession(StopReason.userExit);
          _sessionManager!.startNewSession();
        }
      },
    );
  }
}

// ============================================================
// iOS Reminder Dialog — full-screen countdown dialog for iOS
// ============================================================

class _IOSReminderDialog extends StatefulWidget {
  final ReminderEvent event;
  final Timer? Function() getTimer; // returns Flutter countdown timer (null = ended)
  final VoidCallback onClosed;

  const _IOSReminderDialog({
    required this.event,
    required this.getTimer,
    required this.onClosed,
  });

  @override
  State<_IOSReminderDialog> createState() => _IOSReminderDialogState();
}

class _IOSReminderDialogState extends State<_IOSReminderDialog> {
  late int _countdown;
  bool _countdownFinished = false;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.event.countdownSeconds;

    // Tick every second to update countdown display
    // Check if Flutter timer is still alive
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final timer = widget.getTimer();
      if (timer == null || !timer.isActive) {
        // Flutter timer ended → countdown finished
        setState(() {
          _countdown = 0;
          _countdownFinished = true;
        });
        t.cancel();
        // Auto-close after a brief delay so user sees the checkmark
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            widget.onClosed();
            Navigator.of(context).pop();
          }
        });
      } else {
        setState(() {
          if (_countdown > 0) _countdown--;
        });
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Color get _progressColor {
    if (_countdown <= 5) return Colors.red;
    if (_countdown <= 15) return Colors.orange;
    return const Color(0xFF1A237E);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isEyeRest = widget.event.type == ReminderType.eyeRest;
    final canClose = _countdownFinished || widget.event.meetingMode;

    return PopScope(
      canPop: canClose,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isEyeRest ? '👁️' : '🧘', style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    isEyeRest
                        ? AppStrings.t('eye_rest.title')
                        : AppStrings.t('posture.title'),
                    style: const TextStyle(
                      color: Color(0xFF1A237E),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEyeRest
                        ? AppStrings.t('eye_rest.message')
                        : AppStrings.t('posture.message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF616161), fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 24),

                  // Countdown ring
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: CircularProgressIndicator(
                            value: _countdown / widget.event.countdownSeconds,
                            strokeWidth: 6,
                            backgroundColor: const Color(0xFFE0E0E0),
                            valueColor: AlwaysStoppedAnimation(_progressColor),
                          ),
                        ),
                        Text(
                          _countdownFinished
                              ? '✓'
                              : (widget.event.countdownSeconds >= 60
                                  ? _formatTime(_countdown)
                                : '$_countdown'),
                          style: TextStyle(
                            color: _countdownFinished
                                ? const Color(0xFF10B981)
                                : const Color(0xFF1A237E),
                            fontSize: _countdownFinished ? 36 : 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    _countdownFinished
                        ? AppStrings.t('eye_rest.ready')
                        : AppStrings.t('eye_rest.countdown'),
                    style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                  ),

                  const SizedBox(height: 20),

                  if (canClose)
                    FilledButton(
                      onPressed: () {
                        widget.onClosed();
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        AppStrings.t('eye_rest.close'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    )
                  else
                    Text(
                      AppStrings.t('eye_rest.waiting'),
                      style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
