/// Weekly Plan Screen - Set and manage weekly screen time targets
/// Allows users to set daily screen time goals and tracks progress

import 'package:flutter/material.dart';
import '../models/types.dart';
import '../services/local_store.dart';
import '../utils/i18n.dart';
import '../utils/time_utils.dart';

class WeeklyPlanScreen extends StatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> {
  LocalStore? _store;
  WeeklyPlan? _currentPlan;
  List<DailySummary> _weekSummaries = [];
  bool _loading = true;
  bool _editing = false;

  // Edit state
  late TextEditingController _planController;
  double _editMinutes = 480; // 8 hours default

  @override
  void initState() {
    super.initState();
    _planController = TextEditingController();
    _initData();
  }

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _store = await LocalStore.getInstance();
    await _loadPlan();
    setState(() => _loading = false);
  }

  Future<void> _loadPlan() async {
    if (_store == null) return;

    final today = todayDate();
    final monday = getMonday(today);

    // Load current week plan
    _currentPlan = await _store!.getWeeklyPlan(monday);

    // Load this week's summaries
    final sunday = addDays(monday, 6);
    _weekSummaries = await _store!.querySummaries(startDate: monday, endDate: sunday);

    // If no plan exists, try to auto-fill from last week
    if (_currentPlan == null) {
      final lastMonday = addDays(monday, -7);
      final lastPlan = await _store!.getWeeklyPlan(lastMonday);
      if (lastPlan != null) {
        _editMinutes = lastPlan.plannedDailyMinutes.toDouble();
      } else {
        // Calculate from last week's actual average
        final lastSunday = addDays(monday, -1);
        final lastSummaries = await _store!.querySummaries(startDate: lastMonday, endDate: lastSunday);
        if (lastSummaries.isNotEmpty) {
          final totalSec = lastSummaries.fold(0, (sum, s) => sum + s.totalSeconds);
          final avgSec = totalSec ~/ lastSummaries.length;
          _editMinutes = (avgSec / 60).roundToDouble();
          _editMinutes = _editMinutes.clamp(30, 720);
        }
      }
    } else {
      _editMinutes = _currentPlan!.plannedDailyMinutes.toDouble();
    }

    _planController.text = _editMinutes.round().toString();
  }

  Future<void> _savePlan() async {
    if (_store == null) return;

    final today = todayDate();
    final monday = getMonday(today);
    final minutes = _editMinutes.round();

    if (minutes < 30 || minutes > 720) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.lang.startsWith('zh')
            ? '计划用时需在 30-720 分钟之间'
            : 'Plan must be between 30-720 minutes'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final plan = WeeklyPlan(
      weekStart: monday,
      plannedDailyMinutes: minutes,
      source: _currentPlan == null ? 'auto_from_last_week' : 'user_input',
      createdAt: _currentPlan?.createdAt ?? DateTime.now(),
    );

    await _store!.saveWeeklyPlan(plan);
    setState(() {
      _currentPlan = plan;
      _editing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.lang.startsWith('zh') ? '计划已保存 ✓' : 'Plan saved ✓'),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.lang.startsWith('zh') ? '周计划管理' : 'Weekly Plan'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && !_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
              tooltip: AppStrings.lang.startsWith('zh') ? '编辑计划' : 'Edit Plan',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeekHeader(),
                  const SizedBox(height: 16),
                  if (_editing) _buildEditCard() else _buildPlanCard(),
                  const SizedBox(height: 16),
                  _buildProgressCard(),
                  const SizedBox(height: 16),
                  _buildDailyBreakdown(),
                  const SizedBox(height: 16),
                  _buildTipsCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildWeekHeader() {
    final today = todayDate();
    final monday = getMonday(today);
    final sunday = addDays(monday, 6);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: Column(
          children: [
            const Text('📅', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              AppStrings.lang.startsWith('zh') ? '本周计划' : 'This Week\'s Plan',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$monday ~ $sunday',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard() {
    final hasPlan = _currentPlan != null;
    final plannedMinutes = hasPlan ? _currentPlan!.plannedDailyMinutes : 0;
    final source = hasPlan ? _currentPlan!.source : '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  AppStrings.lang.startsWith('zh') ? '每日计划用时' : 'Daily Time Target',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasPlan) ...[
              Text(
                AppStrings.formatDuration(plannedMinutes * 60),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                source == 'user_input'
                    ? (AppStrings.lang.startsWith('zh') ? '手动设定' : 'Manually set')
                    : (AppStrings.lang.startsWith('zh') ? '根据上周数据自动填入' : 'Auto-filled from last week'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ] else ...[
              Text(
                AppStrings.lang.startsWith('zh') ? '尚未设定本周计划' : 'No plan set for this week',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.add),
                label: Text(AppStrings.lang.startsWith('zh') ? '设定计划' : 'Set Plan'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✏️', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  AppStrings.lang.startsWith('zh') ? '设定每日计划用时' : 'Set Daily Time Target',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current value display
            Center(
              child: Text(
                AppStrings.formatDuration((_editMinutes * 60).round()),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                AppStrings.lang.startsWith('zh')
                    ? '（${_editMinutes.round()} 分钟）'
                    : '(${_editMinutes.round()} minutes)',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Slider
            Slider(
              value: _editMinutes,
              min: 30,
              max: 720,
              divisions: 69,
              label: '${_editMinutes.round()} min',
              activeColor: const Color(0xFF1A237E),
              onChanged: (v) => setState(() {
                _editMinutes = v;
                _planController.text = v.round().toString();
              }),
            ),

            // Quick presets
            const SizedBox(height: 8),
            Text(
              AppStrings.lang.startsWith('zh') ? '快捷设定' : 'Quick Presets',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetChip(120, '2h'),
                _presetChip(240, '4h'),
                _presetChip(360, '6h'),
                _presetChip(480, '8h'),
                _presetChip(600, '10h'),
              ],
            ),

            const SizedBox(height: 16),

            // Manual input
            TextField(
              controller: _planController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.lang.startsWith('zh') ? '手动输入（分钟）' : 'Enter minutes',
                border: const OutlineInputBorder(),
                suffixText: AppStrings.lang.startsWith('zh') ? '分钟' : 'min',
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed >= 30 && parsed <= 720) {
                  setState(() => _editMinutes = parsed.toDouble());
                }
              },
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _editing = false),
                    child: Text(AppStrings.t('common.cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _savePlan,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
                    child: Text(AppStrings.t('common.save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(int minutes, String label) {
    final isSelected = _editMinutes.round() == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF1A237E).withOpacity(0.15),
      onSelected: (_) => setState(() {
        _editMinutes = minutes.toDouble();
        _planController.text = minutes.toString();
      }),
    );
  }

  Widget _buildProgressCard() {
    if (_currentPlan == null) return const SizedBox.shrink();

    final plannedSeconds = _currentPlan!.plannedDailyMinutes * 60;
    final today = todayDate();

    // Calculate this week's stats
    int totalWeekSeconds = 0;
    int daysWithData = 0;
    int daysOverPlan = 0;

    for (final s in _weekSummaries) {
      totalWeekSeconds += s.totalSeconds;
      if (s.totalSeconds > 0) daysWithData++;
      if (s.totalSeconds > plannedSeconds) daysOverPlan++;
    }

    final avgSeconds = daysWithData > 0 ? totalWeekSeconds ~/ daysWithData : 0;
    final weekPlannedTotal = plannedSeconds * 7;

    // Today's data
    final todaySummary = _weekSummaries.where((s) => s.date == today).firstOrNull;
    final todaySeconds = todaySummary?.totalSeconds ?? 0;
    final todayRatio = plannedSeconds > 0 ? todaySeconds / plannedSeconds : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  AppStrings.lang.startsWith('zh') ? '本周进度' : 'Week Progress',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Today's progress bar
            Text(
              AppStrings.lang.startsWith('zh') ? '今日用时' : 'Today',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: todayRatio.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  todayRatio > 1.0 ? Colors.red : (todayRatio > 0.8 ? Colors.orange : const Color(0xFF3949AB)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.formatDuration(todaySeconds),
                  style: TextStyle(
                    color: todayRatio > 1.0 ? Colors.red : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${AppStrings.lang.startsWith('zh') ? '计划' : 'Plan'}: ${AppStrings.formatDuration(plannedSeconds)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Week stats
            Row(
              children: [
                _weekStat(
                  '📅',
                  AppStrings.lang.startsWith('zh') ? '本周累计' : 'Week Total',
                  AppStrings.formatDuration(totalWeekSeconds),
                ),
                _weekStat(
                  '📊',
                  AppStrings.lang.startsWith('zh') ? '日均' : 'Daily Avg',
                  AppStrings.formatDuration(avgSeconds),
                ),
                _weekStat(
                  '⚠️',
                  AppStrings.lang.startsWith('zh') ? '超计划天数' : 'Days Over',
                  '$daysOverPlan / ${_weekSummaries.length}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekStat(String emoji, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A237E))),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown() {
    if (_currentPlan == null || _weekSummaries.isEmpty) return const SizedBox.shrink();

    final plannedSeconds = _currentPlan!.plannedDailyMinutes * 60;
    final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final monday = getMonday(todayDate());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.lang.startsWith('zh') ? '每日明细' : 'Daily Breakdown',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...List.generate(7, (i) {
              final date = addDays(monday, i);
              final summary = _weekSummaries.where((s) => s.date == date).firstOrNull;
              final seconds = summary?.totalSeconds ?? 0;
              final ratio = plannedSeconds > 0 ? seconds / plannedSeconds : 0.0;
              final isToday = date == todayDate();
              final dayName = AppStrings.lang.startsWith('zh') ? days[i] : daysEn[i];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? const Color(0xFF1A237E) : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          // Background bar (plan)
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Actual usage bar
                          FractionallySizedBox(
                            widthFactor: ratio.clamp(0.0, 1.5),
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: ratio > 1.0
                                    ? Colors.red.withOpacity(0.7)
                                    : (ratio > 0.8 ? Colors.orange.withOpacity(0.7) : const Color(0xFF3949AB).withOpacity(0.7)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          // Plan line
                          Positioned(
                            left: (1.0 / (ratio > 1.5 ? ratio : 1.5) * 100).clamp(0, 100).toDouble(),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        seconds > 0 ? AppStrings.formatDuration(seconds) : '-',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ratio > 1.0 ? Colors.red : Colors.black87,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12, height: 12, color: const Color(0xFF3949AB).withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(AppStrings.lang.startsWith('zh') ? '正常' : 'OK', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
                Container(width: 12, height: 12, color: Colors.orange.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(AppStrings.lang.startsWith('zh') ? '接近计划' : 'Near limit', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
                Container(width: 12, height: 12, color: Colors.red.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(AppStrings.lang.startsWith('zh') ? '超计划' : 'Over', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
                Container(width: 2, height: 12, color: Colors.black54),
                const SizedBox(width: 4),
                Text(AppStrings.lang.startsWith('zh') ? '计划线' : 'Plan', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 ${AppStrings.lang.startsWith('zh') ? '健康用屏建议' : 'Healthy Screen Tips'}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.lang.startsWith('zh')
                  ? '• 世界卫生组织建议成人每天屏幕用时不超过 2 小时（娱乐用途）\n'
                    '• 工作用途的屏幕时间建议每 20 分钟休息 20 秒\n'
                    '• 保持 50-70cm 的屏幕距离\n'
                    '• 睡前 1 小时避免使用屏幕'
                  : '• WHO recommends ≤2 hours of recreational screen time daily\n'
                    '• Take a 20-second break every 20 minutes\n'
                    '• Maintain 50-70cm distance from screen\n'
                    '• Avoid screens 1 hour before sleep',
              style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
