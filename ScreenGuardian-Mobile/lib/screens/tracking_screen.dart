/// Tracking Screen - LLM Ranking display

import 'package:flutter/material.dart';
import '../utils/i18n.dart';
import '../services/ranking_service.dart';
import '../models/types.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _rankingService = RankingService();
  LLMRankingRecord? _data;
  bool _loading = false;
  String? _error;
  String _sortColumn = 'rank';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = await _rankingService.getRanking();
    setState(() {
      _loading = false;
      _data = data;
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = await _rankingService.fetchFromAPI();
    setState(() {
      _loading = false;
      if (data != null) {
        _data = data;
      } else {
        _error = AppStrings.lang.startsWith('zh') ? '获取失败，请稍后重试' : 'Fetch failed, please retry';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('tracking.title')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _refreshData,
                        child: Text(AppStrings.t('tracking.refresh')),
                      ),
                    ],
                  ),
                )
              : _data == null || _data!.data.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📡', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text(AppStrings.lang.startsWith('zh')
                              ? '暂无数据'
                              : 'No data'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _refreshData,
                            child: Text(AppStrings.t('tracking.refresh')),
                          ),
                        ],
                      ),
                    )
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final entries = _getSortedEntries();

    // Calculate totals
    final totalRevenue = _data!.data.fold(0, (sum, e) => sum + (e.weeklyRevenue ?? 0));
    final totalPrompt = _data!.data.fold(0, (sum, e) => sum + (e.promptTokens ?? 0));
    final totalCompletion = _data!.data.fold(0, (sum, e) => sum + (e.completionTokens ?? 0));

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _summaryCard('💰', AppStrings.formatRevenue(totalRevenue), 'Revenue'),
                const SizedBox(width: 8),
                _summaryCard('📥', AppStrings.formatTokens(totalPrompt), 'Prompt'),
                const SizedBox(width: 8),
                _summaryCard('📤', AppStrings.formatTokens(totalCompletion), 'Output'),
              ],
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${AppStrings.t('tracking.source')}: OpenRouter',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${_data!.weekStart} ~ ${_data!.weekEnd}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: _getSortColumnIndex(),
              sortAscending: _sortAscending,
              columns: [
                DataColumn(
                  label: Text('#'),
                  numeric: true,
                  onSort: (i, asc) => _sort('rank', asc),
                ),
                DataColumn(
                  label: Text(AppStrings.t('tracking.model')),
                  onSort: (i, asc) => _sort('modelName', asc),
                ),
                DataColumn(
                  label: Text(AppStrings.t('tracking.provider')),
                  onSort: (i, asc) => _sort('provider', asc),
                ),
                DataColumn(
                  label: Text(AppStrings.t('tracking.prompt_tokens')),
                  numeric: true,
                  onSort: (i, asc) => _sort('promptTokens', asc),
                ),
                DataColumn(
                  label: Text(AppStrings.t('tracking.completion_tokens')),
                  numeric: true,
                  onSort: (i, asc) => _sort('completionTokens', asc),
                ),
                DataColumn(
                  label: Text(AppStrings.t('tracking.weekly_revenue')),
                  numeric: true,
                  onSort: (i, asc) => _sort('weeklyRevenue', asc),
                ),
              ],
              rows: entries.map((e) => DataRow(
                cells: [
                  DataCell(Text('${e.rank}')),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(e.modelName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  DataCell(Text(e.provider)),
                  DataCell(Text(AppStrings.formatTokens(e.promptTokens))),
                  DataCell(Text(AppStrings.formatTokens(e.completionTokens))),
                  DataCell(Text(
                    AppStrings.formatRevenue(e.weeklyRevenue),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
                  )),
                ],
              )).toList(),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _summaryCard(String emoji, String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  List<RankingEntry> _getSortedEntries() {
    if (_data == null) return [];
    final entries = List<RankingEntry>.from(_data!.data);

    int compare(dynamic a, dynamic b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      if (a is String) return a.compareTo(b);
      return (a as num).compareTo(b as num);
    }

    entries.sort((a, b) {
      dynamic va, vb;
      switch (_sortColumn) {
        case 'rank': va = a.rank; vb = b.rank; break;
        case 'modelName': va = a.modelName; vb = b.modelName; break;
        case 'provider': va = a.provider; vb = b.provider; break;
        case 'promptTokens': va = a.promptTokens; vb = b.promptTokens; break;
        case 'completionTokens': va = a.completionTokens; vb = b.completionTokens; break;
        case 'weeklyRevenue': va = a.weeklyRevenue; vb = b.weeklyRevenue; break;
        default: va = a.rank; vb = b.rank;
      }
      final result = compare(va, vb);
      return _sortAscending ? result : -result;
    });

    return entries;
  }

  int _getSortColumnIndex() {
    switch (_sortColumn) {
      case 'rank': return 0;
      case 'modelName': return 1;
      case 'provider': return 2;
      case 'promptTokens': return 3;
      case 'completionTokens': return 4;
      case 'weeklyRevenue': return 5;
      default: return 0;
    }
  }

  void _sort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
  }
}
