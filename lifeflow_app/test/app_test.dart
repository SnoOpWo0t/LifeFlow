import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeflow_app/core/network/api_client.dart';
import 'package:lifeflow_app/core/storage/storage_service.dart';
import 'package:lifeflow_app/core/utils/formatters.dart';
import 'package:lifeflow_app/features/calendar/domain/calendar_models.dart';
import 'package:lifeflow_app/features/expenses/domain/expense_models.dart';
import 'package:lifeflow_app/features/expenses/presentation/screens/category_management_dialog.dart';
import 'package:lifeflow_app/features/expenses/data/expense_repository.dart';
import 'package:lifeflow_app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:lifeflow_app/features/scan/data/scan_repository.dart';
import 'package:lifeflow_app/features/scan/presentation/scan_sheet.dart';
import 'package:lifeflow_app/features/scan/domain/scan_result.dart';
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
    test(
      'WishlistItem parses PostgreSQL string numbers and SQLite numbers',
      () {
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
      },
    );

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

    test(
      'Wishlist category filter and categories provider work accurately',
      () async {
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
      },
    );
  });

  group('photo scanner', () {
    test('reads a receipt result', () {
      final result = ScanResult.fromJson({
        'kind': 'receipt',
        'receipt': {
          'merchant': 'Shwapno',
          'date': '2026-10-12',
          'items': [
            {
              'name': 'Rice',
              'amount': 450,
              'category': 'Food',
              'new_category': false,
            },
          ],
          'extras': [
            {'name': 'VAT', 'amount': '22.5'},
          ],
          'discount': 10,
          'total': 462.5,
        },
      });
      expect(result, isA<ScannedReceipt>());
      final receipt = result as ScannedReceipt;
      expect(receipt.items.single.category, 'Food');
      expect(receipt.extras.single.amount, 22.5);
    });

    test('reads notes and wishlist results', () {
      final notes =
          ScanResult.fromJson({
                'kind': 'notes',
                'notes': {
                  'date': '',
                  'entries': [
                    {
                      'type': 'income',
                      'name': 'Salary',
                      'amount': 50000,
                      'category': 'Salary',
                      'new_category': true,
                      'date': '',
                    },
                  ],
                },
              })
              as ScannedNotes;
      expect(notes.entries.single.type, 'income');
      expect(notes.entries.single.newCategory, isTrue);

      final wishlist =
          ScanResult.fromJson({
                'kind': 'wishlist',
                'wishlist': {
                  'items': [
                    {
                      'title': 'Lamp',
                      'price': 900,
                      'priority': 'high',
                      'category': 'Home',
                      'note': '',
                      'link': '',
                    },
                  ],
                },
              })
              as ScannedWishlist;
      expect(wishlist.items.single.priority, 'high');
    });

    test('discount shares add up exactly and favour bigger lines', () {
      final shares = discountShares([100, 50, 50], 10);
      expect(shares, [5.0, 2.5, 2.5]);

      final odd = discountShares([33.33, 33.33, 33.34], 10);
      expect((odd.fold<double>(0, (a, b) => a + b) * 100).round(), 1000);
      expect(discountShares([100], 0), [0]);
    });

    test('detects the photo type from its bytes', () {
      expect(imageMimeType([0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
      expect(
        imageMimeType([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
        'image/png',
      );
      expect(
        imageMimeType('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits),
        'image/webp',
      );
      expect(imageMimeType('GIF89a-not-supported'.codeUnits), isNull);
    });
  });

  testWidgets(
    'scan review: edit, share the discount, create missing categories',
    (tester) async {
      final expenses = _FakeExpenseRepository();
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scanRepositoryProvider.overrideWithValue(_FakeScanRepository()),
            expenseRepositoryProvider.overrideWithValue(expenses),
            categoriesProvider.overrideWith(
              (ref) async => [
                ExpenseCategory(id: 1, name: 'Food', type: 'expense'),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ScanReviewSheet(bytes: [0xFF, 0xD8], target: 'money'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt: Shwapno'), findsOneWidget);
      expect(find.text('Toiletries (new)'), findsOneWidget);
      // 600 + 300 + VAT 45, minus a 90 discount.
      expect(find.textContaining('Total ৳ 855.00'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(expenses.createdCategories, ['Toiletries']);
      // The discount is shared 2:1 between the two items; VAT stays whole.
      expect(
        [for (final t in expenses.transactions) t['amount']],
        [540.0, 270.0, 45.0],
      );
      expect(expenses.transactions.first['category_id'], 1);
      expect(expenses.transactions[1]['category_id'], 99);
      expect(
        expenses.transactions.every((t) => t['account'] == 'cash'),
        isTrue,
      );
    },
  );
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

class _FakeScanRepository implements ScanRepository {
  @override
  Future<ScanResult> scan(List<int> bytes, String target) async =>
      const ScannedReceipt(
        merchant: 'Shwapno',
        date: '',
        items: [
          ScannedLine(name: 'Rice', amount: 600, category: 'Food'),
          ScannedLine(
            name: 'Shampoo',
            amount: 300,
            category: 'Toiletries',
            newCategory: true,
          ),
        ],
        extras: [ScannedLine(name: 'VAT', amount: 45)],
        discount: 90,
        total: 855,
      );
}

class _FakeExpenseRepository implements ExpenseRepository {
  final transactions = <Map<String, dynamic>>[];
  final createdCategories = <String>[];

  @override
  Future<ExpenseCategory> createCategory(Map<String, dynamic> data) async {
    createdCategories.add(data['name'] as String);
    return ExpenseCategory(
      id: 99,
      name: data['name'] as String,
      type: data['type'] as String,
    );
  }

  @override
  Future<Transaction> addTransaction(Map<String, dynamic> data) async {
    transactions.add(data);
    return Transaction(
      id: transactions.length,
      amount: (data['amount'] as num).toDouble(),
      type: data['type'] as String,
      transactionDate: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
