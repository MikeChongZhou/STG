/// Posture Change Reminder Dialog - White card style matching desktop

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/i18n.dart';

class PostureChangeDialog extends StatefulWidget {
  final int countdownSeconds;
  final bool meetingMode;
  final VoidCallback onClosed;

  const PostureChangeDialog({
    super.key,
    required this.countdownSeconds,
    required this.meetingMode,
    required this.onClosed,
  });

  @override
  State<PostureChangeDialog> createState() => _PostureChangeDialogState();
}

class _PostureChangeDialogState extends State<PostureChangeDialog> {
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
                  const Text('🧘', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.t('posture.title'),
                    style: const TextStyle(
                      color: Color(0xFF1A237E),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.t('posture.message'),
                    style: const TextStyle(color: Color(0xFF616161), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.t('posture.health_tip'),
                    style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
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
                            fontSize: _countdown <= 0 ? 36 : 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
                        AppStrings.t('posture.confirm'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    )
                  else
                    Text(
                      AppStrings.lang.startsWith('zh') ? '请完成姿势切换...' : 'Please change posture...',
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
