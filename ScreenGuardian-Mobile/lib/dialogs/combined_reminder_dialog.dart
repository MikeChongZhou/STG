/// Combined Reminder Dialog - Eye Rest + Posture Change
/// Shown every 40 minutes (every 2nd eye rest cycle)
/// Displays both "change posture" and "look 20ft away for 20s"

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/i18n.dart';

class CombinedReminderDialog extends StatefulWidget {
  final int countdownSeconds;
  final bool meetingMode;
  final VoidCallback onClosed;

  const CombinedReminderDialog({
    super.key,
    required this.countdownSeconds,
    required this.meetingMode,
    required this.onClosed,
  });

  @override
  State<CombinedReminderDialog> createState() => _CombinedReminderDialogState();
}

class _CombinedReminderDialogState extends State<CombinedReminderDialog> {
  late int _countdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.countdownSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          t.cancel();
          widget.onClosed();
          if (mounted) Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  Color get _progressColor {
    if (_countdown <= 10) return Colors.red;
    if (_countdown <= 30) return Colors.orange;
    return const Color(0xFF1A237E);
  }

  @override
  Widget build(BuildContext context) {
    final canClose = _countdown <= 0 || widget.meetingMode;

    return PopScope(
      canPop: canClose,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icons row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🧘', style: TextStyle(fontSize: 40)),
                      SizedBox(width: 12),
                      Text('+', style: TextStyle(fontSize: 24, color: Colors.grey)),
                      SizedBox(width: 12),
                      Text('👁️', style: TextStyle(fontSize: 40)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    AppStrings.t('combined.title'),
                    style: const TextStyle(
                      color: Color(0xFF1A237E),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Posture instruction
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('🧘', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.t('combined.posture_msg'),
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Eye rest instruction
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('👁️', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.t('combined.eye_msg'),
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Countdown
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: _countdown / widget.countdownSeconds,
                            strokeWidth: 6,
                            backgroundColor: const Color(0xFFE0E0E0),
                            valueColor: AlwaysStoppedAnimation(_progressColor),
                          ),
                        ),
                        Text(
                          _countdown <= 0 ? '✓' : _formatTime(_countdown),
                          style: TextStyle(
                            color: _countdown <= 0 ? const Color(0xFF10B981) : const Color(0xFF1A237E),
                            fontSize: _countdown <= 0 ? 32 : 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _countdown <= 0
                        ? AppStrings.t('eye_rest.ready')
                        : AppStrings.t('combined.countdown_label'),
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
                      AppStrings.t('combined.waiting'),
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
