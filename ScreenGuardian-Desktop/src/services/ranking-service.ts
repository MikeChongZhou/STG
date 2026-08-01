/**
 * Ranking Service - Fetch LLM Ranking data from OpenRouter
 * Matches the Flutter mobile ranking_service.dart logic
 */

import * as https from 'https';
import { LLMRankingRecord, RankingEntry } from './types';
import { todayDate, getMonday, addDays } from '../utils/time-utils';

const RANKING_API = 'https://openrouter.ai/api/frontend/v1/rankings/models?view=week';
const PRICING_API_BASE = 'https://openrouter.ai/api/frontend/v1/stats/effective-pricing';
const TOP_N = 20;

export class RankingService {
  private cachedRecord: LLMRankingRecord | null = null;
  private _fetching = false;

  async getRanking(): Promise<LLMRankingRecord | null> {
    if (this.cachedRecord) {
      const currentWeekStart = getMonday(todayDate());
      if (this.cachedRecord.weekStart === currentWeekStart) {
        return this.cachedRecord;
      }
    }
    return this.fetchFromAPI();
  }

  async fetchFromAPI(): Promise<LLMRankingRecord | null> {
    if (this._fetching) return null;
    this._fetching = true;

    try {
      // Step 1: Fetch weekly rankings
      const rankingsData = await this.httpGet(RANKING_API);
      const rankingsJson = JSON.parse(rankingsData);
      const dataList: any[] = rankingsJson.data || [];

      // Sort by total_prompt_tokens descending, take top N
      const sorted = dataList
        .filter(item => (item.total_prompt_tokens || 0) > 0)
        .sort((a, b) => (b.total_prompt_tokens || 0) - (a.total_prompt_tokens || 0));

      const topModels = sorted.slice(0, TOP_N);

      // Step 2: Fetch pricing for each model
      const entries: RankingEntry[] = [];
      for (let i = 0; i < topModels.length; i++) {
        const item = topModels[i];
        const permaslug = item.model_permaslug as string;
        const promptTokens = item.total_prompt_tokens || 0;
        const completionTokens = item.total_completion_tokens || 0;
        const requestCount = item.count || 0;

        let inputPrice = 0, outputPrice = 0;
        try {
          const pricingUrl = `${PRICING_API_BASE}?permaslug=${encodeURIComponent(permaslug)}&variant=standard`;
          const pricingData = await this.httpGet(pricingUrl);
          const pricingJson = JSON.parse(pricingData);
          if (pricingJson.data) {
            inputPrice = pricingJson.data.weightedInputPrice || 0;
            outputPrice = pricingJson.data.weightedOutputPrice || 0;
          }
        } catch {
          // Continue with price = 0
        }

        const weeklyRevenue = Math.round(
          (promptTokens * inputPrice / 1000000 + completionTokens * outputPrice / 1000000)
        );

        entries.push({
          rank: i + 1,
          modelId: permaslug,
          modelName: this.formatModelName(permaslug),
          provider: this.extractProvider(permaslug),
          promptTokens,
          completionTokens,
          inputPricePerMToken: inputPrice,
          outputPricePerMToken: outputPrice,
          weeklyRevenue,
          requestCount,
        });
      }

      // Step 3: Build record
      const currentWeekStart = getMonday(todayDate());
      const record: LLMRankingRecord = {
        weekStart: currentWeekStart,
        weekEnd: addDays(currentWeekStart, 6),
        fetchedAt: new Date().toISOString(),
        fetchedBy: 'desktop',
        source: RANKING_API,
        data: entries,
      };

      this.cachedRecord = record;
      return record;
    } catch (e) {
      console.error('[RankingService] Fetch failed:', e);
      return null;
    } finally {
      this._fetching = false;
    }
  }

  private httpGet(url: string): Promise<string> {
    return new Promise((resolve, reject) => {
      https.get(url, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          if (res.statusCode === 200) {
            resolve(data);
          } else {
            reject(new Error(`HTTP ${res.statusCode}`));
          }
        });
      }).on('error', reject);
    });
  }

  private formatModelName(permaslug: string): string {
    const parts = permaslug.split('/');
    if (parts.length < 2) return permaslug;
    let name = parts[1];
    name = name.replace(/-\d{8}$/, '');
    name = name.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
    return name;
  }

  private extractProvider(permaslug: string): string {
    const parts = permaslug.split('/');
    if (parts.length < 2) return 'Unknown';
    const provider = parts[0];
    return provider.charAt(0).toUpperCase() + provider.slice(1);
  }

  get isFetching(): boolean { return this._fetching; }
}
