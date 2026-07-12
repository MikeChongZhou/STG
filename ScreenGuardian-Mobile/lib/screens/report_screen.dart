/// Report Screen - Real data reports with session details

import 'package:flutter/material.dart';
import '../models/types.dart';
import '../services/local_store.dart';
import '../utils/i18n.dart';
import '../utils/time_utils.dart';

class ReportScreen extends StatefulWidget {
  final VoidCallback? onBeforeGenerate;

  const ReportScreen({super.key, this.onBeforeGenerate});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _mode = 'daily';
  DateTime _selectedDate = DateTime.now();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();

  List<ScreenSession> _sessions = [];
  List<DailySummary> _summaries = [];
  bool _loading = false;
  LocalStore? _store;

  @override
  void initState() {
    super.initState();
    _initStore();
  }

  Future<void> _initStore() async {
    _store = await LocalStore.getInstance();
    _generateReport();
  }

  Future<void> _generateReport() async {
    if (_store == null) return;
    setState(() => _loading = true);

    // Notify main app to pause/resume current session
    widget.onBeforeGenerate?.call();
    // Small delay to let the session save
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      if (_mode == 'daily') {
        final date = formatDate(_selectedDate);
        _sessions = await _store!.querySessions(startDate: date, endDate: date);
        final summary = await _store!.getDailySummary(date);
        _summaries = summary != null ? [summary] : [];
      } else {
        _sessions = await _store!.querySessions(
          startDate: formatDate(_startDate),
          endDate: formatDate(_endDate),
        );
        _summaries = await _store!.querySummaries(
          startDate: formatDate(_startDate),
          endDate: formatDate(_endDate),
        );
      }
    } catch (e) {
      print('[Report] Error generating report: $e');
      _sessions = [];
      _summaries = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('report.title')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'daily', label: Text(AppStrings.t('report.daily'))),
                        ButtonSegment(value: 'range', label: Text(AppStrings.t('report.range'))),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (v) {
                        setState(() => _mode = v.first);
                        _generateReport();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_mode == 'daily')
                      ListTile(
                        title: Text(AppStrings.t('report.date')),
                        subtitle: Text(formatDate(_selectedDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) {
                            setState(() => _selectedDate = d);
                            _generateReport();
                          }
                        },
                      )
                    else
                      Column(
                        children: [
                          ListTile(
                            title: Text(AppStrings.t('report.start_date')),
                            subtitle: Text(formatDate(_startDate)),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                setState(() => _startDate = d);
                                _generateReport();
                              }
                            },
                          ),
                          ListTile(
                            title: Text(AppStrings.t('report.end_date')),
                            subtitle: Text(formatDate(_endDate)),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                setState(() => _endDate = d);
                                _generateReport();
                              }
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_summaries.isEmpty && _sessions.isEmpty)
              _buildEmptyState()
            else ...[
              _buildSummaryCard(),
              const SizedBox(height: 16),
              if (_mode == 'range' && _summaries.length > 1) ...[
                _buildDailyBreakdown(),
                const SizedBox(height: 16),
              ],
              _buildSessionList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Text('📊', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              AppStrings.t('report.empty'),
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.lang.startsWith('zh')
                  ? '开始使用 ScreenGuardian 后，这里将显示用时报告'
                  : 'Start using ScreenGuardian to see your screen time report here',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalSeconds = _mode == 'daily'
        ? (_summaries.isNotEmpty ? _summaries.first.totalSeconds : 0)
        : _summaries.fold(0, (sum, s) => sum + s.totalSeconds);

    final sessionCount = _mode == 'daily'
        ? (_summaries.isNotEmpty ? _summaries.first.sessionCount : 0)
        : _summaries.fold(0, (sum, s) => sum + s.sessionCount);

    final dayCount = _mode == 'range' ? _summaries.length : 1;
    final avgSeconds = dayCount > 0 ? totalSeconds ~/ dayCount : 0;

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
            Text(
              _mode == 'daily'
                  ? '${formatDate(_selectedDate)} ${getDayOfWeek(formatDate(_selectedDate))}'
                  : '${formatDate(_startDate)} ~ ${formatDate(_endDate)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.formatDuration(totalSeconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              AppStrings.t('report.total_time'),
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statBadge('📱', '$sessionCount', AppStrings.lang.startsWith('zh') ? '次使用' : 'sessions'),
                if (_mode == 'range') ...[
                  _statBadge('📅', '$dayCount', AppStrings.lang.startsWith('zh') ? '天' : 'days'),
                  _statBadge('📊', AppStrings.formatDuration(avgSeconds), AppStrings.t('report.daily_average')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildDailyBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.t('report.daily_breakdown') , style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            ...(_summaries.reversed.take(14).map((s) {
              final maxSeconds = _summaries.fold(0, (max, e) => e.totalSeconds > max ? e.totalSeconds : max);
              final ratio = maxSeconds > 0 ? s.totalSeconds / maxSeconds : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${s.date.substring(5)} ${getDayOfWeek(s.date)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 16,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            s.totalSeconds > 7200 ? Colors.red : (s.totalSeconds > 3600 ? Colors.orange : const Color(0xFF3949AB)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 65,
                      child: Text(
                        AppStrings.formatDuration(s.totalSeconds),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.t('report.session_detail'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            ..._sessions.reversed.take(50).map((s) => _sessionTile(s)),
          ],
        ),
      ),
    );
  }

  Widget _sessionTile(ScreenSession s) {
    final reasonText = s.stopReason != null ? AppStrings.translateStopReason(s.stopReason!.name) : '-';
    final duration = AppStrings.formatDuration(s.durationSeconds ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: (s.durationSeconds ?? 0) > 3600 ? Colors.red : const Color(0xFF3949AB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatTime(s.startTime)} - ${s.endTime != null ? formatTime(s.endTime!) : '...'}',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  '$duration · $reasonText',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            s.deviceName,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
