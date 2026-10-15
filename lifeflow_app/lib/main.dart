import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/local/local_providers.dart';
import 'core/local/open_local_db.dart';
import 'core/network/api_client.dart';
import 'core/storage/storage_service.dart';
import 'core/sync/sync_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (!kIsWeb) await StorageService(prefs).forgetUnusableServer();
  final db = await openLocalDb();
  try {
    ApiClient.deviceTimezone =
        (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    // Unknown: the server falls back to its default timezone.
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localDbProvider.overrideWithValue(db),
      ],
      child: const LifeFlowApp(),
    ),
  );
}

class LifeFlowApp extends ConsumerWidget {
  const LifeFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Keeps background sync running while signed in (no rebuilds).
    ref.listen(syncProvider, (_, _) {});

    return MaterialApp(
      title: 'LifeFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // Only the very first token check gets a splash. A login/register request
      // keeps the previous (null) user, so AuthScreen stays mounted and shows
      // its own progress and error states instead of being swapped out.
      home: authState.value != null
          ? const MainScreen()
          : authState.hasValue || authState.hasError
          ? const AuthScreen()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
