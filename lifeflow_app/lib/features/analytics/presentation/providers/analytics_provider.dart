import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/analytics_repository.dart';
import '../../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(apiClientProvider));
});

final weeklyAnalyticsProvider = FutureProvider.autoDispose<WeeklyAnalytics>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.fetchWeeklyStats();
});
