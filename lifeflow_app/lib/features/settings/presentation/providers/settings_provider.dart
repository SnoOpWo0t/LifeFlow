import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(apiClientProvider), ref.watch(sharedPreferencesProvider));
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, bool>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(settingsRepositoryProvider).isDarkMode;
  }
  
  void setMode(bool isDark) {
    state = isDark;
  }
}
