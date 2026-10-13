import '../../../core/network/api_client.dart';
import '../domain/calendar_models.dart';

class CalendarRepository {
  final ApiClient _apiClient;

  CalendarRepository(this._apiClient);

  Future<CalendarMonth> fetchMonth(DateTime month) async {
    final response = await _apiClient.dio.get(
      '/calendar',
      queryParameters: {'month': dateKey(month).substring(0, 7)},
    );
    return CalendarMonth.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CalendarDayDetail> fetchDay(DateTime day) async {
    final response = await _apiClient.dio.get(
      '/calendar/day',
      queryParameters: {'date': dateKey(day)},
    );
    return CalendarDayDetail.fromJson(response.data as Map<String, dynamic>);
  }
}
