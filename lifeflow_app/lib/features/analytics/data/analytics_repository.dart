import '../../../core/network/api_client.dart';
import '../domain/analytics_models.dart';

class AnalyticsRepository {
  final ApiClient _apiClient;

  AnalyticsRepository(this._apiClient);

  Future<WeeklyAnalytics> fetchWeeklyStats() async {
    try {
      final response = await _apiClient.dio.get('/analytics/weekly');
      return WeeklyAnalytics.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch analytics: $e');
    }
  }
}
