/// Ranking Service - Fetch LLM Ranking data from OpenRouter

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/types.dart';
import '../utils/time_utils.dart';

class RankingService {
  static const String _rankingApi = 'https://openrouter.ai/api/frontend/v1/rankings/models?view=week';
  static const String _pricingApiBase = 'https://openrouter.ai/api/frontend/v1/stats/effective-pricing';
  static const int _topN = 20;

  LLMRankingRecord? _cachedRecord;
  bool _fetching = false;

  /// Get ranking data - returns cached if available, otherwise fetches
  Future<LLMRankingRecord?> getRanking() async {
    if (_cachedRecord != null) {
      final currentWeekStart = getMonday(todayDate());
      if (_cachedRecord!.weekStart == currentWeekStart) {
        return _cachedRecord;
      }
    }
    return fetchFromAPI();
  }

  /// Fetch ranking data from OpenRouter API
  Future<LLMRankingRecord?> fetchFromAPI() async {
    if (_fetching) return null;
    _fetching = true;

    try {
      // Step 1: Fetch weekly rankings
      final rankingsResponse = await http.get(Uri.parse(_rankingApi));
      if (rankingsResponse.statusCode != 200) {
        throw Exception('Rankings API failed: ${rankingsResponse.statusCode}');
      }

      final rankingsJson = jsonDecode(rankingsResponse.body);
      final List<dynamic> dataList = rankingsJson['data'] ?? [];

      // Sort by total_prompt_tokens descending, take top N
      final sorted = dataList
          .where((item) => ((item['total_prompt_tokens'] as num?)?.toInt() ?? 0) > 0)
          .toList()
        ..sort((a, b) => ((b['total_prompt_tokens'] as num?)?.toInt() ?? 0)
            .compareTo((a['total_prompt_tokens'] as num?)?.toInt() ?? 0));

      final topModels = sorted.take(_topN).toList();

      // Step 2: Fetch pricing for each model
      final entries = <RankingEntry>[];

      for (int i = 0; i < topModels.length; i++) {
        final item = topModels[i];
        final permaslug = item['model_permaslug'] as String;
        final promptTokens = (item['total_prompt_tokens'] as num?)?.toInt() ?? 0;
        final completionTokens = (item['total_completion_tokens'] as num?)?.toInt() ?? 0;
        final requestCount = (item['count'] as num?)?.toInt() ?? 0;

        double inputPrice = 0;
        double outputPrice = 0;

        try {
          final pricingUrl = '$_pricingApiBase?permaslug=${Uri.encodeComponent(permaslug)}&variant=standard';
          final pricingResponse = await http.get(Uri.parse(pricingUrl));

          if (pricingResponse.statusCode == 200) {
            final pricingJson = jsonDecode(pricingResponse.body);
            final data = pricingJson['data'];
            if (data != null) {
              inputPrice = (data['weightedInputPrice'] as num?)?.toDouble() ?? 0;
              outputPrice = (data['weightedOutputPrice'] as num?)?.toDouble() ?? 0;
            }
          }
        } catch (e) {
          // Continue with price = 0
        }

        // Calculate weekly revenue (prices are per 1M tokens)
        final weeklyRevenue = (promptTokens * inputPrice / 1000000 +
                completionTokens * outputPrice / 1000000)
            .round();

        final modelName = _formatModelName(permaslug);
        final provider = _extractProvider(permaslug);

        entries.add(RankingEntry(
          rank: i + 1,
          modelId: permaslug,
          modelName: modelName,
          provider: provider,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          inputPricePerMToken: inputPrice,
          outputPricePerMToken: outputPrice,
          weeklyRevenue: weeklyRevenue,
          requestCount: requestCount,
        ));
      }

      // Step 3: Build record
      final currentWeekStart = getMonday(todayDate());
      final record = LLMRankingRecord(
        weekStart: currentWeekStart,
        weekEnd: addDays(currentWeekStart, 6),
        fetchedAt: DateTime.now(),
        fetchedBy: 'mobile',
        source: _rankingApi,
        data: entries,
      );

      _cachedRecord = record;
      return record;
    } catch (e) {
      print('[RankingService] Fetch failed: $e');
      return null;
    } finally {
      _fetching = false;
    }
  }

  String _formatModelName(String permaslug) {
    final parts = permaslug.split('/');
    if (parts.length < 2) return permaslug;

    var name = parts[1];
    name = name.replaceAll(RegExp(r'-\d{8}$'), '');
    name = name.split('-').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    return name;
  }

  String _extractProvider(String permaslug) {
    final parts = permaslug.split('/');
    if (parts.length < 2) return 'Unknown';
    final provider = parts[0];
    return provider[0].toUpperCase() + provider.substring(1);
  }

  bool get isFetching => _fetching;
}
