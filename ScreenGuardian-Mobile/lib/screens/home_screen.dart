/// Home Screen - Main menu for mobile
/// All elements fit in one screen, adaptive sizing

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/p2p_sync_service.dart';
import '../utils/i18n.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'tracking_screen.dart';
import 'weekly_plan_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  final int currentElapsedSeconds;
  final int todayTotalSeconds;
  final P2PSyncService? p2pSync;
  final VoidCallback? onBeforeReport;
  final dynamic reminderManager; // ReminderManager

  const HomeScreen({
    super.key,
    required this.currentElapsedSeconds,
    required this.todayTotalSeconds,
    this.p2pSync,
    this.onBeforeReport,
    this.reminderManager,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenH < 700; // 小屏手机

    // 根据屏幕高度自适应间距
    final outerPad = isSmall ? 12.0 : 20.0;
    final headerGap = isSmall ? 10.0 : 16.0;
    final gridGap = isSmall ? 8.0 : 12.0;
    final bottomGap = isSmall ? 6.0 : 12.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(outerPad),
          child: Column(
            children: [
              // ── Header card — compact ──
              _buildHeader(isSmall),

              SizedBox(height: headerGap),

              // ── Menu grid — 2×3, fills remaining space ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gridH = constraints.maxHeight;
                    final gridW = constraints.maxWidth;
                    final spacing = gridGap;
                    // 3 rows
                    final cellH = (gridH - spacing * 2) / 3;
                    final cellW = (gridW - spacing) / 2;
                    final ratio = cellW / cellH;

                    return GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: ratio,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _menuCard('📊', AppStrings.t('menu.report'), isSmall, () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ReportScreen(onBeforeGenerate: widget.onBeforeReport),
                          ));
                        }),
                        _menuCard('🎯', AppStrings.lang.startsWith('zh') ? '周计划' : 'Weekly Plan', isSmall, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyPlanScreen()));
                        }),
                        _menuCard('⚙️', AppStrings.t('menu.settings'), isSmall, () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => SettingsScreen(p2pSync: widget.p2pSync, reminderManager: widget.reminderManager),
                          ));
                        }),
                        _menuCard('📡', AppStrings.t('menu.tracking'), isSmall, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingScreen()));
                        }),
                        _menuCard('ℹ️', AppStrings.t('menu.about'), isSmall, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                        }),
                      ],
                    );
                  },
                ),
              ),

              SizedBox(height: bottomGap),

              // ── Sync status ──
              if (widget.p2pSync?.isRunning == true)
                Padding(
                  padding: EdgeInsets.only(bottom: isSmall ? 4 : 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.lang.startsWith('zh') ? '局域网同步运行中' : 'LAN sync running',
                        style: TextStyle(color: Colors.green[600], fontSize: 11),
                      ),
                      if (widget.p2pSync?.isPaired == true) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.lock, size: 11, color: Colors.green[600]),
                      ],
                    ],
                  ),
                ),

              // ── Exit button ──
              SizedBox(
                width: double.infinity,
                height: isSmall ? 40 : 46,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmExit(context),
                  icon: Icon(Icons.exit_to_app, size: isSmall ? 18 : 20),
                  label: Text(
                    AppStrings.t('menu.exit'),
                    style: TextStyle(fontSize: isSmall ? 13 : 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header card ──
  Widget _buildHeader(bool isSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 14 : 20,
          vertical: isSmall ? 10 : 14,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
          ),
        ),
        child: Row(
          children: [
            Text('🛡️', style: TextStyle(fontSize: isSmall ? 22 : 28)),
            SizedBox(width: isSmall ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'ScreenGuardian',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'V$appVersion',
                  style: TextStyle(color: Colors.white70, fontSize: isSmall ? 10 : 11),
                ),
              ],
              ),
            ),
            const Spacer(),
            _statItem(
              '⏱️',
              AppStrings.formatDuration(widget.currentElapsedSeconds),
              AppStrings.lang.startsWith('zh') ? '本次' : 'Current',
              isSmall,
            ),
            SizedBox(width: isSmall ? 12 : 20),
            _statItem(
              '📊',
              AppStrings.formatDuration(widget.todayTotalSeconds),
              AppStrings.lang.startsWith('zh') ? '今日' : 'Today',
              isSmall,
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat item ──
  Widget _statItem(String emoji, String value, String label, bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$emoji $value',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmall ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: isSmall ? 9 : 10),
        ),
      ],
    );
  }

  // ── Menu card ──
  Widget _menuCard(String emoji, String label, bool isSmall, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: isSmall ? 24 : 30)),
            SizedBox(height: isSmall ? 4 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 11 : 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Exit confirmation ──
  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('menu.exit')),
        content: Text(AppStrings.lang.startsWith('zh')
            ? '确定要退出应用吗？'
            : 'Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            child: Text(AppStrings.t('common.ok')),
          ),
        ],
      ),
    );
  }
}
