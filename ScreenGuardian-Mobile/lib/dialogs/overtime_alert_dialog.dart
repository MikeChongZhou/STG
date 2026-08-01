/// Overtime Alert Dialog - Shown when screen time exceeds daily plan
/// Supports first-time alert and repeated reminders

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/i18n.dart';

class OvertimeAlertDialog extends StatelessWidget {
  final int totalSeconds;
  final int plannedSeconds;
  final bool isFirst;
  final VoidCallback? onTakeBreak;
  final VoidCallback onContinue;

  const OvertimeAlertDialog({
    super.key,
    required this.totalSeconds,
    required this.plannedSeconds,
    this.isFirst = true,
    this.onTakeBreak,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final exceeded = totalSeconds - plannedSeconds;
    final exceededRatio = plannedSeconds > 0 ? (totalSeconds / plannedSeconds) : 1.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Text(
              isFirst ? '⚠️' : '⏰',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isFirst
                  ? AppStrings.t('overtime.title')
                  : AppStrings.t('overtime.title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _statRow(
                    '📊',
                    AppStrings.lang.startsWith('zh') ? '今日累计' : 'Today Total',
                    // TODO: add proper i18n key
                    AppStrings.formatDuration(totalSeconds),
                    Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  _statRow(
                    '📝',
                    AppStrings.lang.startsWith('zh') ? '计划用时' : 'Planned',
                    // TODO: add proper i18n key
                    AppStrings.formatDuration(plannedSeconds),
                    const Color(0xFF1A237E),
                  ),
                  const Divider(height: 16),
                  _statRow(
                    '⚡',
                    AppStrings.lang.startsWith('zh') ? '已超出' : 'Exceeded',
                    // TODO: add proper i18n key
                    AppStrings.formatDuration(exceeded),
                    const Color(0xFFD32F2F),
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress bar showing how far over plan
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: exceededRatio.clamp(0.0, 2.0) / 2.0,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Color(0xFFD32F2F)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(exceededRatio * 100).round()}%',
              style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 12),
            ),

            if (isFirst) ...[
              const SizedBox(height: 12),
              Text(
                AppStrings.t('overtime.exceeded'),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                if (!isFirst && onTakeBreak != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onTakeBreak?.call();
                      },
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text(AppStrings.lang.startsWith('zh') ? '休息一下' : 'Take a Break'),
                      // TODO: add proper i18n key
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (!isFirst && onTakeBreak != null) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onContinue();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: isFirst ? const Color(0xFF1A237E) : const Color(0xFFD32F2F),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isFirst
                          ? AppStrings.t('overtime.acknowledge')
                          : AppStrings.lang.startsWith('zh') ? '继续使用' : 'Continue',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String emoji, String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Show the overtime alert dialog
  static void show(
    BuildContext context, {
    required int totalSeconds,
    required int plannedSeconds,
    bool isFirst = true,
    VoidCallback? onTakeBreak,
    VoidCallback? onContinue,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OvertimeAlertDialog(
        totalSeconds: totalSeconds,
        plannedSeconds: plannedSeconds,
        isFirst: isFirst,
        onTakeBreak: onTakeBreak,
        onContinue: onContinue ?? () {},
      ),
    );
  }
}
