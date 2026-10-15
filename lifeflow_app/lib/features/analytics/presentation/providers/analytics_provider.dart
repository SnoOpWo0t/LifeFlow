import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../data/analytics_repository.dart';
import '../../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(localDbProvider));
});

final weeklyAnalyticsProvider = FutureProvider.autoDispose<WeeklyAnalytics>((
  ref,
) {
  ref.watch(dataVersionProvider);
  return ref.watch(analyticsRepositoryProvider).fetchWeeklyStats();
});
