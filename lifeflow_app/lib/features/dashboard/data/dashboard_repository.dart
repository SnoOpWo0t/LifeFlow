import '../../../core/network/api_client.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository(this._apiClient);

  Future<DashboardSummary> fetchSummary() async {
    final response = await _apiClient.dio.get('/dashboard/summary');
    return DashboardSummary.fromJson(response.data);
  }
}
