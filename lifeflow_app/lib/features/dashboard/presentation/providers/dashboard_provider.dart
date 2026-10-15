import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return DashboardRepository(
    ref.watch(localDbProvider),
    () => settings.monthlyBudget,
  );
});

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) {
  ref.watch(dataVersionProvider);
  return ref.watch(dashboardRepositoryProvider).fetchSummary();
});
