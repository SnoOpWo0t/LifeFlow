import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeflow_app/core/network/api_client.dart';
import 'package:lifeflow_app/core/network/api_constants.dart';
import 'package:lifeflow_app/core/storage/storage_service.dart';
import 'package:lifeflow_app/core/utils/formatters.dart';
import 'package:lifeflow_app/features/calendar/domain/calendar_models.dart';
import 'package:lifeflow_app/features/expenses/domain/expense_models.dart';
import 'package:lifeflow_app/features/expenses/presentation/screens/category_management_dialog.dart';
import 'package:lifeflow_app/features/expenses/data/expense_repository.dart';
import 'package:lifeflow_app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:lifeflow_app/features/scan/data/scan_repository.dart';
import 'package:lifeflow_app/features/scan/presentation/scan_sheet.dart';
import 'package:lifeflow_app/features/insights/domain/ai_insight.dart';
import 'package:lifeflow_app/features/scan/domain/scan_result.dart';
import 'package:lifeflow_app/features/settings/data/settings_repository.dart';
import 'package:lifeflow_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:lifeflow_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:lifeflow_app/features/dashboard/presentation/providers/weather_provider.dart';
import 'package:lifeflow_app/features/settings/domain/weather_location.dart';
import 'package:lifeflow_app/features/wishlist/domain/wishlist_item.dart';
import 'package:lifeflow_app/features/wishlist/domain/wishlist_category_utils.dart';
import 'package:lifeflow_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:lifeflow_app/features/savings/domain/savings_models.dart';
import 'package:lifeflow_app/features/savings/domain/savings_goal_models.dart';
import 'package:lifeflow_app/features/bills/domain/bill_models.dart';
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

    test('masks amounts when isVault is true', () {
      expect(formatMoney(124123, isVault: true), '৳ ••••••');
      expect(formatMoney(-500, isVault: true), '৳ ••••••');
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

  test('server addresses typed on the phone become API URLs', () {
    expect(
      ApiConstants.normalizeServer(' 192.168.0.105:8000 '),
      'http://192.168.0.105:8000/api/v1',
    );
    expect(
      ApiConstants.normalizeServer('https://lifeflow-api.onrender.com/'),
      'https://lifeflow-api.onrender.com/api/v1',
    );
    expect(
      ApiConstants.normalizeServer('https://x.com/api/v1'),
      'https://x.com/api/v1',
    );
    // A hosted API typed without a scheme gets https (http is redirected).
    expect(
      ApiConstants.normalizeServer('lifeflow-api-x1y2.onrender.com'),
      'https://lifeflow-api-x1y2.onrender.com/api/v1',
    );
    expect(
      ApiConstants.normalizeServer('localhost:8000'),
      'http://localhost:8000/api/v1',
    );
    expect(ApiConstants.normalizeServer(''), isNull);
    expect(ApiConstants.normalizeServer('ftp://x.com'), isNull);
  });

  testWidgets('the server address can be changed from the sign-in screen', (
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

    await tester.tap(find.text('Server: 127.0.0.1:8000'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '192.168.0.105:8000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Server: 192.168.0.105:8000'), findsOneWidget);
    expect(prefs.getString('server_url'), 'http://192.168.0.105:8000/api/v1');
  });

  test('requests go to the server chosen on the phone', () async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'http://192.168.0.105:8000/api/v1',
    });
    final client = ApiClient(
      StorageService(await SharedPreferences.getInstance()),
    );
    late String sentTo;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sentTo = options.uri.toString();
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    await expectLater(client.dio.get('/user'), throwsA(isA<DioException>()));
    expect(sentTo, 'http://192.168.0.105:8000/api/v1/user');
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

  group('transactions', () {
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
          'id': 'w1',
          'title': 'Mechanical Keyboard',
          'estimated_price': '150.75',
          'priority': 'HIGH',
          'is_purchased': 1,
        });
        expect(fromPostgres.estimatedPrice, 150.75);
        expect(fromPostgres.priority, 'high');
        expect(fromPostgres.isPurchased, isTrue);

        final fromSqlite = WishlistItem.fromJson({
          'id': 'w2',
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
          id: '1',
          title: 'Laptop',
          estimatedPrice: 1000,
          isPurchased: true,
        ),
        WishlistItem(
          id: '2',
          title: 'Monitor',
          estimatedPrice: 300,
          isPurchased: false,
        ),
        WishlistItem(
          id: '3',
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
        'id': '10',
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
          WishlistItem(id: '1', title: 'Perfume Bottle', category: 'Perfume'),
          WishlistItem(id: '2', title: 'Mechanical Keyboard', category: 'Tech'),
          WishlistItem(id: '3', title: 'Mystery Gift'),
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
                ExpenseCategory(id: 'food', name: 'Food', type: 'expense'),
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
      expect(expenses.transactions.first['category_id'], 'food');
      expect(expenses.transactions[1]['category_id'], 'new');
      expect(
        expenses.transactions.every((t) => t['account'] == 'cash'),
        isTrue,
      );
    },
  );

  testWidgets('scan review: unpriced wishlist items can be added', (
    tester,
  ) async {
    final added = <Map<String, dynamic>>[];
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanRepositoryProvider.overrideWithValue(_FakeWishlistScan()),
          wishlistProvider.overrideWith(() => _RecordingWishlist(added)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ScanReviewSheet(bytes: [0xFF, 0xD8], target: 'wishlist'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Neither item has a price, but both count as selected.
    expect(find.text('2 of 2 selected'), findsOneWidget);
    await tester.tap(find.text('Add to wishlist'));
    await tester.pumpAndSettle();

    expect([for (final i in added) i['title']], ['Eggs (12)', 'Desk lamp']);
    expect(added.first.containsKey('estimated_price'), isFalse);
  });

  test('AI summary state parses saved and missing summaries', () {
    final saved = InsightState.fromJson({
      'period': 'week',
      'from': '2026-10-12',
      'to': '2026-10-18',
      'configured': true,
      'stale': true,
      'insight': {
        'headline': 'A calm week',
        'summary': 'You spent ৳4,500 so far.',
        'highlights': ['Food is your top category'],
        'suggestions': [
          {'title': 'Cook at home', 'detail': 'Saves money.', 'area': 'money'},
        ],
        'generated_at': '2026-10-15T10:33:15+06:00',
      },
    });
    expect(saved.insight!.headline, 'A calm week');
    expect(saved.insight!.suggestions.single.area, 'money');
    expect(saved.insight!.generatedAt, isNotNull);
    expect(saved.stale, isTrue);

    final none = InsightState.fromJson({
      'period': 'month',
      'configured': false,
      'insight': null,
    });
    expect(none.insight, isNull);
    expect(none.configured, isFalse);
  });

  group('savings models & summary', () {
    test('Saving model parses fromJson and serializes toJson accurately', () {
      final s = Saving.fromJson({
        'id': 'save-123',
        'amount': '2500.50',
        'type': 'deposit',
        'account': 'bkash',
        'note': 'Emergency fund deposit',
        'transaction_date': '2026-10-16',
      });
      expect(s.id, 'save-123');
      expect(s.amount, 2500.50);
      expect(s.isDeposit, isTrue);
      expect(s.isWithdrawal, isFalse);
      expect(s.account, 'bkash');
      expect(s.note, 'Emergency fund deposit');
      expect(s.transactionDate.year, 2026);
      expect(s.transactionDate.month, 10);
      expect(s.transactionDate.day, 16);

      final json = s.toJson();
      expect(json['amount'], 2500.50);
      expect(json['type'], 'deposit');
      expect(json['account'], 'bkash');
      expect(json['note'], 'Emergency fund deposit');
      expect(json['transaction_date'], '2026-10-16');
    });

    test('SavingsAccountMeta maps key to correct label, icon, and color', () {
      final bank = SavingsAccountMeta.forAccount('bank');
      expect(bank.label, 'Bank');
      expect(bank.key, 'bank');

      final bkash = SavingsAccountMeta.forAccount('bKash');
      expect(bkash.label, 'bKash');
      expect(bkash.key, 'bkash');

      final fallback = SavingsAccountMeta.forAccount('unknown');
      expect(fallback.key, 'cash');
    });
  });

  group('transaction search and filtering', () {
    final sampleTransactions = [
      Transaction(
        id: 'tx-1',
        amount: 1500,
        type: 'expense',
        account: 'bkash',
        transactionDate: DateTime(2026, 10, 15),
        note: 'Grocery market shopping',
        category: ExpenseCategory(id: 'c1', name: 'Food', type: 'expense'),
      ),
      Transaction(
        id: 'tx-2',
        amount: 25000,
        type: 'income',
        account: 'bank',
        transactionDate: DateTime(2026, 10, 14),
        note: 'Monthly salary credit',
        category: ExpenseCategory(id: 'c2', name: 'Salary', type: 'income'),
      ),
      Transaction(
        id: 'tx-3',
        amount: 350,
        type: 'expense',
        account: 'cash',
        transactionDate: DateTime(2026, 10, 16),
        note: 'Rickshaw fare',
        category: ExpenseCategory(id: 'c3', name: 'Transport', type: 'expense'),
      ),
    ];

    test('search query matches note or category name', () {
      final results = sampleTransactions.where((tx) {
        const query = 'grocery';
        final noteMatch = tx.note?.toLowerCase().contains(query) ?? false;
        final catMatch = tx.category?.name.toLowerCase().contains(query) ?? false;
        return noteMatch || catMatch;
      }).toList();

      expect(results.length, 1);
      expect(results.first.id, 'tx-1');
    });

    test('type and wallet filtering work accurately', () {
      // Filter by income
      final income = sampleTransactions.where((tx) => tx.type == 'income').toList();
      expect(income.length, 1);
      expect(income.first.id, 'tx-2');

      // Filter by bkash
      final bkash = sampleTransactions.where((tx) => tx.account == 'bkash').toList();
      expect(bkash.length, 1);
      expect(bkash.first.id, 'tx-1');
    });
  });

  group('dashboard customization settings', () {
    test('defaultDashboardSections has all 10 sections enabled', () {
      final defaults = SettingsRepository.defaultDashboardSections;
      expect(defaults['weather'], isTrue);
      expect(defaults['productivity'], isTrue);
      expect(defaults['stats'], isTrue);
      expect(defaults['calendar'], isTrue);
      expect(defaults['budget'], isTrue);
      expect(defaults['accounts'], isTrue);
      expect(defaults['savings'], isTrue);
      expect(defaults['savings_goals'], isTrue);
      expect(defaults['wishlist'], isTrue);
      expect(defaults['recent'], isTrue);
    });
  });

  group('Bills and Recurring Payments', () {
    test('Bill model fromJson and toJson round trip', () {
      final json = {
        'id': 'bill-1',
        'title': 'Internet Fiber',
        'amount': '1500.00',
        'due_date': '2026-11-01',
        'frequency': 'monthly',
        'account': 'bank',
        'is_paid': false,
        'note': 'Optical link',
      };

      final bill = Bill.fromJson(json);
      expect(bill.id, 'bill-1');
      expect(bill.title, 'Internet Fiber');
      expect(bill.amount, 1500.0);
      expect(bill.frequency, 'monthly');
      expect(bill.isPaid, isFalse);

      final encoded = bill.toJson();
      expect(encoded['title'], 'Internet Fiber');
      expect(encoded['amount'], 1500.0);
      expect(encoded['due_date'], '2026-11-01');
      expect(encoded['frequency'], 'monthly');
    });

    test('Bill calculates due status correctly', () {
      final overdueBill = Bill(
        id: '1',
        title: 'Electricity',
        amount: 2000,
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(overdueBill.isOverdue, isTrue);
      expect(overdueBill.dueStatusText, contains('Overdue by 2 days'));

      final paidBill = Bill(
        id: '2',
        title: 'Gas',
        amount: 500,
        dueDate: DateTime.now(),
        isPaid: true,
      );
      expect(paidBill.isPaid, isTrue);
      expect(paidBill.dueStatusText, 'Paid');
    });
  });

  group('Savings Goals', () {
    test('SavingsGoal model calculates progress and remaining amounts accurately', () {
      final goal = SavingsGoal(
        id: 'goal-1',
        title: 'MacBook M3',
        targetAmount: 200000,
        savedAmount: 50000,
        category: 'Tech & Gadgets',
      );

      expect(goal.progressRatio, 0.25);
      expect(goal.remainingAmount, 150000);
      expect(goal.isCompleted, isFalse);
    });

    test('SavingsGoal fromJson and toJson round trip', () {
      final json = {
        'id': 'g-1',
        'title': 'Emergency Fund',
        'target_amount': '100000',
        'saved_amount': '100000',
        'is_completed': true,
        'category': 'Emergency',
      };

      final goal = SavingsGoal.fromJson(json);
      expect(goal.id, 'g-1');
      expect(goal.targetAmount, 100000.0);
      expect(goal.savedAmount, 100000.0);
      expect(goal.isCompleted, isTrue);
      expect(goal.progressRatio, 1.0);
    });
  });
}

class _MockWishlistNotifier extends AsyncNotifier<List<WishlistItem>>
    implements WishlistNotifier {
  final List<WishlistItem> _initial;
  _MockWishlistNotifier(this._initial);

  @override
  List<WishlistItem> build() => _initial;

  @override
  Future<void> addItem(Map<String, dynamic> data) async {}

  @override
  Future<void> updateItem(String id, Map<String, dynamic> data) async {}

  @override
  Future<void> togglePurchased(WishlistItem item) async {}

  @override
  Future<void> deleteItem(String id) async {}

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
      id: 'new',
      name: data['name'] as String,
      type: data['type'] as String,
    );
  }

  @override
  Future<Transaction> addTransaction(Map<String, dynamic> data) async {
    transactions.add(data);
    return Transaction(
      id: '${transactions.length}',
      amount: (data['amount'] as num).toDouble(),
      type: data['type'] as String,
      transactionDate: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWishlistScan implements ScanRepository {
  @override
  Future<ScanResult> scan(List<int> bytes, String target) async =>
      const ScannedWishlist(
        items: [
          ScannedWishItem(title: 'Eggs (12)', category: 'Groceries'),
          ScannedWishItem(title: 'Desk lamp', priority: 'high'),
        ],
      );
}

class _RecordingWishlist extends _MockWishlistNotifier {
  _RecordingWishlist(this.added) : super(const []);
  final List<Map<String, dynamic>> added;

  @override
  Future<void> addItem(Map<String, dynamic> data) async => added.add(data);
}
