import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeflow_app/core/network/api_client.dart';
import 'package:lifeflow_app/core/storage/storage_service.dart';
import 'package:lifeflow_app/core/utils/formatters.dart';
import 'package:lifeflow_app/features/calendar/domain/calendar_models.dart';
import 'package:lifeflow_app/features/expenses/domain/expense_models.dart';
import 'package:lifeflow_app/features/expenses/presentation/screens/category_management_dialog.dart';
import 'package:lifeflow_app/features/settings/data/settings_repository.dart';
import 'package:lifeflow_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:lifeflow_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:lifeflow_app/features/dashboard/presentation/providers/weather_provider.dart';
import 'package:lifeflow_app/features/settings/domain/weather_location.dart';
import 'package:lifeflow_app/features/wishlist/domain/wishlist_item.dart';
import 'package:lifeflow_app/features/wishlist/domain/wishlist_category_utils.dart';
import 'package:lifeflow_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('formatMoney', () {
    test('adds thousands separators', () {
      expect(formatMoney(124123), '৳ 124,123');
      expect(formatMoney(999), '৳ 999');
      expect(formatMoney(1500.5, decimals: 2), '৳ 1,500.50');
    });

    test('puts the minus sign before the currency', () {
      expect(formatMoney(-2500), '-৳ 2,500');
    });
  });

  group('WeatherLocation', () {
    test('label skips missing parts', () {
      const dhaka = WeatherLocation(
        name: 'Dhaka',
        country: 'Bangladesh',
        latitude: 23.7,
        longitude: 90.4,
      );
      const nowhere = WeatherLocation(
        name: 'Current location',
        latitude: 0,
        longitude: 0,
      );
      expect(dhaka.label, 'Dhaka, Bangladesh');
      expect(nowhere.label, 'Current location');
    });

    test('survives a JSON round trip', () {
      final copy = WeatherLocation.fromJson(WeatherLocation.fallback.toJson());
      expect(copy.label, WeatherLocation.fallback.label);
      expect(copy.latitude, WeatherLocation.fallback.latitude);
    });
  });

  test('weather codes map to readable descriptions', () {
    Weather withCode(int code, {bool isDay = true}) => Weather(
      location: WeatherLocation.fallback,
      temperature: 20,
      feelsLike: 20,
      humidity: 50,
      windSpeed: 5,
      code: code,
      isDay: isDay,
    );
    expect(withCode(0).description, 'Clear sky');
    expect(withCode(0, isDay: false).description, 'Clear night');
    expect(withCode(63).description, 'Rain');
    expect(withCode(95).description, 'Thunderstorm');
    expect(withCode(12345).description, 'Unknown');
  });

  testWidgets('sign-in form validates input before calling the API', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The submit button is the last "Sign in" (the first is the mode switch).
    await tester.tap(find.text('Sign in').last);
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  group('appearance setting', () {
    Future<SettingsRepository> repoWith(Map<String, Object> saved) async {
      SharedPreferences.setMockInitialValues(saved);
      final prefs = await SharedPreferences.getInstance();
      return SettingsRepository(ApiClient(StorageService(prefs)), prefs);
    }

    test('follows the device by default', () async {
      expect((await repoWith({})).themeMode, ThemeMode.system);
    });

    test('keeps the old on/off dark-mode choice', () async {
      expect(
        (await repoWith({'is_dark_mode': true})).themeMode,
        ThemeMode.dark,
      );
    });

    test('uses the new System/Light/Dark choice when present', () async {
      final repo = await repoWith({
        'is_dark_mode': true,
        'theme_mode': 'light',
      });
      expect(repo.themeMode, ThemeMode.light);
    });
  });

  test('category colours parse safely', () {
    expect(categoryColor('#22C55E'), const Color(0xFF22C55E));
    expect(categoryColor('#'), Colors.grey); // what the old dialog used to save
    expect(categoryColor('#zzzzzz'), Colors.grey);
    expect(categoryColor(null), Colors.grey);
  });

  group('paginated transactions', () {
    Map<String, dynamic> page(int current, int last) => {
      'data': [
        {
          'id': 1,
          'amount': '760.00', // PostgreSQL sends decimals as text
          'type': 'expense',
          'transaction_date': '2026-10-13',
          'category': {
            'id': 2,
            'name': 'Food',
            'type': 'expense',
            'color_hex': '#F97316',
          },
        },
      ],
      'meta': {'current_page': current, 'last_page': last},
    };

    test('knows when more pages exist', () {
      final first = TransactionPage.fromJson(page(1, 3));
      expect(first.items.single.amount, 760);
      expect(first.items.single.category?.name, 'Food');
      expect(first.hasMore, isTrue);
      expect(TransactionPage.fromJson(page(3, 3)).hasMore, isFalse);
    });

    test('category totals parse numbers sent as text', () {
      final spending = CategorySpending.fromJson({
        'name': 'Food',
        'color_hex': '#F97316',
        'total': '1250.5',
      });
      expect(spending.total, 1250.5);
    });
  });

  group('calendar', () {
    test('month grid is 6 full weeks starting on a Monday', () {
      final grid = monthGrid(DateTime(2026, 10));
      expect(grid.length, 42);
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.first, DateTime(2026, 9, 28)); // 1 Oct 2026 is a Thursday
      expect(grid.contains(DateTime(2026, 10, 31)), isTrue);
    });

    test('reads the month summary keyed by date', () {
      final month = CalendarMonth.fromJson({
        'month': '2026-10',
        'habits_total': 2,
        'days': [
          {
            'date': '2026-10-14',
            'tasks_due': 2,
            'tasks_done': 1,
            'habits_done': 2,
            'spent': '760.5',
            'earned': 0,
          },
        ],
      });
      final day = month.days[dateKey(DateTime(2026, 10, 14))]!;
      expect(month.habitsTotal, 2);
      expect(day.tasksDue, 2);
      expect(day.spent, 760.5);
      expect(month.days[dateKey(DateTime(2026, 10, 15))], isNull);
    });
  });

  group('wishlist', () {
    test('WishlistItem parses PostgreSQL string numbers and SQLite numbers', () {
      final fromPostgres = WishlistItem.fromJson({
        'id': 1,
        'title': 'Mechanical Keyboard',
        'estimated_price': '150.75',
        'priority': 'HIGH',
        'is_purchased': 1,
      });
      expect(fromPostgres.estimatedPrice, 150.75);
      expect(fromPostgres.priority, 'high');
      expect(fromPostgres.isPurchased, isTrue);

      final fromSqlite = WishlistItem.fromJson({
        'id': 2,
        'title': 'Coffee Beans',
        'estimated_price': 20,
        'is_purchased': false,
      });
      expect(fromSqlite.estimatedPrice, 20.0);
      expect(fromSqlite.priority, 'normal');
      expect(fromSqlite.isPurchased, isFalse);
    });

    test('WishlistStats calculates progress and totals accurately', () async {
      final items = [
        WishlistItem(
          id: 1,
          title: 'Laptop',
          estimatedPrice: 1000,
          isPurchased: true,
        ),
        WishlistItem(
          id: 2,
          title: 'Monitor',
          estimatedPrice: 300,
          isPurchased: false,
        ),
        WishlistItem(
          id: 3,
          title: 'Desk',
          estimatedPrice: 200,
          isPurchased: false,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          wishlistProvider.overrideWith(() => _MockWishlistNotifier(items)),
        ],
      );

      await container.read(wishlistProvider.future);
      final stats = container.read(wishlistStatsProvider);
      expect(stats.totalCount, 3);
      expect(stats.wantedCount, 2);
      expect(stats.purchasedCount, 1);
      expect(stats.totalValue, 1500);
      expect(stats.purchasedValue, 1000);
      expect(stats.wantedValue, 500);
      expect(stats.progress, closeTo(1 / 3, 0.001));
    });

    test('WishlistItem parses and serializes custom category properly', () {
      final item = WishlistItem.fromJson({
        'id': 10,
        'title': 'Dior Sauvage Elixir',
        'estimated_price': 160.0,
        'category': 'Perfume',
        'priority': 'high',
      });

      expect(item.category, 'Perfume');
      expect(item.toJson()['category'], 'Perfume');

      final updated = item.copyWith(category: 'Fragrance');
      expect(updated.category, 'Fragrance');

      final cleared = item.copyWith(clearCategory: true);
      expect(cleared.category, isNull);
      expect(cleared.toJson().containsKey('category'), isFalse);
    });

    test('WishlistCategoryUtils assigns appropriate icons and colors', () {
      expect(WishlistCategoryUtils.getIcon('Perfume'), Icons.spa);
      expect(WishlistCategoryUtils.getIcon('Tech'), Icons.devices);
      expect(WishlistCategoryUtils.getIcon('Gaming'), Icons.sports_esports);
      expect(WishlistCategoryUtils.getIcon('Books'), Icons.menu_book);

      final perfumeColor = WishlistCategoryUtils.getColor('Perfume');
      expect(perfumeColor, const Color(0xFFD946EF));

      final techColor = WishlistCategoryUtils.getColor('Tech');
      expect(techColor, const Color(0xFF0284C7));
    });

    test('Wishlist category filter and categories provider work accurately', () async {
      final items = [
        WishlistItem(id: 1, title: 'Perfume Bottle', category: 'Perfume'),
        WishlistItem(id: 2, title: 'Mechanical Keyboard', category: 'Tech'),
        WishlistItem(id: 3, title: 'Mystery Gift'),
      ];

      final container = ProviderContainer(
        overrides: [
          wishlistProvider.overrideWith(() => _MockWishlistNotifier(items)),
        ],
      );

      await container.read(wishlistProvider.future);

      final categories = container.read(wishlistCategoriesProvider);
      expect(categories, ['Perfume', 'Tech']);

      // Initial filter: all
      expect(container.read(filteredWishlistProvider).length, 3);

      // Filter by Perfume
      container
          .read(wishlistCategoryFilterProvider.notifier)
          .setCategory('Perfume');
      final perfumeItems = container.read(filteredWishlistProvider);
      expect(perfumeItems.length, 1);
      expect(perfumeItems.first.title, 'Perfume Bottle');

      // Filter by Tech
      container
          .read(wishlistCategoryFilterProvider.notifier)
          .setCategory('Tech');
      final techItems = container.read(filteredWishlistProvider);
      expect(techItems.length, 1);
      expect(techItems.first.title, 'Mechanical Keyboard');
    });
  });
}

class _MockWishlistNotifier extends AsyncNotifier<List<WishlistItem>>
    implements WishlistNotifier {
  final List<WishlistItem> _initial;
  _MockWishlistNotifier(this._initial);

  @override
  Future<List<WishlistItem>> build() async => _initial;

  @override
  Future<void> addItem(Map<String, dynamic> data) async {}

  @override
  Future<void> updateItem(int id, Map<String, dynamic> data) async {}

  @override
  Future<void> togglePurchased(WishlistItem item) async {}

  @override
  Future<void> deleteItem(int id) async {}

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {}
}
