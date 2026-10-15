import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/ai_insight.dart';

class InsightException implements Exception {
  final String message;
  const InsightException(this.message);
  @override
  String toString() => message;
}

class InsightsRepository {
  final ApiClient _apiClient;
  InsightsRepository(this._apiClient);

  /// The saved summary for the current [period] (no AI call).
  Future<InsightState> fetch(String period) async {
    final response = await _apiClient.dio.get(
      '/insights',
      queryParameters: {'period': period},
    );
    return InsightState.fromJson(response.data as Map<String, dynamic>);
  }

  /// Writes a fresh summary with the AI (counts toward a daily limit).
  Future<InsightState> generate(String period) async {
    try {
      final response = await _apiClient.dio.post(
        '/insights',
        data: {'period': period},
        options: Options(receiveTimeout: const Duration(seconds: 75)),
      );
      return InsightState.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message'] : null;
      throw InsightException(
        message is String && message.isNotEmpty
            ? message
            : e.type == DioExceptionType.receiveTimeout
            ? 'The AI took too long. Try again.'
            : "Couldn't reach the AI. Check your connection.",
      );
    }
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(ref.watch(apiClientProvider));
});

/// The saved summary per period ('week' | 'month').
final insightProvider = FutureProvider.autoDispose.family<InsightState, String>(
  (ref, period) {
    return ref.watch(insightsRepositoryProvider).fetch(period);
  },
);
