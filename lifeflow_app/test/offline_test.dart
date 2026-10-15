import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeflow_app/core/local/local_db.dart';
import 'package:lifeflow_app/core/local/local_providers.dart';
import 'package:lifeflow_app/core/network/api_client.dart';
import 'package:lifeflow_app/core/storage/storage_service.dart';
import 'package:lifeflow_app/core/sync/sync_service.dart';
import 'package:lifeflow_app/core/utils/dates.dart';
import 'package:lifeflow_app/features/auth/data/auth_data_source.dart';
import 'package:lifeflow_app/features/auth/data/auth_repository.dart';
import 'package:lifeflow_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:lifeflow_app/features/dashboard/data/dashboard_repository.dart';
import 'package:lifeflow_app/features/expenses/data/expense_repository.dart';
import 'package:lifeflow_app/features/habits/data/habit_repository.dart';
import 'package:lifeflow_app/features/habits/domain/habit_models.dart';
import 'package:lifeflow_app/features/tasks/data/task_repository.dart';
import 'package:lifeflow_app/features/tasks/domain/task.dart';
import 'package:lifeflow_app/features/tasks/presentation/providers/task_provider.dart';
import 'package:lifeflow_app/features/wishlist/data/wishlist_repository.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

var _dbCount = 0;
Future<LocalDb> _freshDb() =>
    LocalDb.open(databaseFactoryMemory, 'test-${_dbCount++}.db');

Task _task(String title, {DateTime? due, String? rule}) => Task(
  id: '',
  title: title,
  status: 'todo',
  priority: 'medium',
  dueDate: due,
  recurrenceRule: rule,
);

void main() {
  group('device database', () {
    test('keeps records across restarts and tracks unsynced edits', () async {
      final name = 'restart-${_dbCount++}.db';
      final db = await LocalDb.open(databaseFactoryMemory, name);
      final saved = await db.save('tasks', {'title': 'Pay rent'});
      expect(saved['id'], hasLength(36));
      expect(db.pendingCount, 1);

      final reopened = await LocalDb.open(databaseFactoryMemory, name);
      expect(reopened.get('tasks', saved['id'])?['title'], 'Pay rent');
      expect(reopened.dirty('tasks'), hasLength(1));
    });

    test('a delete is a tombstone until the server has it', () async {
      final db = await _freshDb();
      final r = await db.save('tasks', {'title': 'Old'});
      await db.markSynced('tasks', [r]);
      expect(db.pendingCount, 0);

      await db.delete('tasks', r['id']);
      expect(db.all('tasks'), isEmpty);
      final tombstone = db.dirty('tasks').single;
      expect(tombstone['deleted_at'], isNotNull);

      await db.markSynced('tasks', [tombstone]);
      expect(db.getAny('tasks', r['id']), isNull);
    });

    test(
      'a newer unsynced edit here beats an older one from the server',
      () async {
        final db = await _freshDb();
        final r = await db.save('tasks', {'title': 'Mine, newer'});
        await db.applyRemote('tasks', [
          {
            'id': r['id'],
            'title': 'Theirs, older',
            'updated_at': '2000-01-01T00:00:00.000Z',
          },
        ]);
        expect(db.get('tasks', r['id'])?['title'], 'Mine, newer');

        await db.applyRemote('tasks', [
          {
            'id': r['id'],
            'title': 'Theirs, newer',
            'updated_at': '2999-01-01T00:00:00.000Z',
          },
        ]);
        expect(db.get('tasks', r['id'])?['title'], 'Theirs, newer');
        expect(db.pendingCount, 0);
      },
    );
  });

  group('works without a server', () {
    test('a recurring task marked done moves to its next date', () async {
      final repo = TaskRepository(await _freshDb());
      final task = await repo.createTask(
        _task('Gym', due: DateTime(2026, 10, 15, 7), rule: 'weekly'),
      );
      final next = await repo.updateTask(task.copyWith(status: 'done'));
      expect(next.status, 'todo');
      expect(next.dueDate, DateTime(2026, 10, 22, 7));
    });

    test('habit streaks: today pending keeps yesterday\'s streak', () {
      final today = DateTime(2026, 10, 15);
      final s = streaksFor({
        '2026-10-10',
        '2026-10-11',
        '2026-10-13',
        '2026-10-14',
      }, today);
      expect(s.current, 2);
      expect(s.longest, 2);
      expect(streaksFor({'2026-10-12'}, today).current, 0);
    });

    test('checking a habit twice in a day undoes it', () async {
      final db = await _freshDb();
      final repo = HabitRepository(db);
      final habit = await repo.createHabit(
        Habit(
          id: '',
          name: 'Read',
          currentStreak: 0,
          longestStreak: 0,
          logs: const [],
        ),
      );
      final checked = await repo.toggleHabit(habit.id);
      expect(checked.currentStreak, 1);
      expect(checked.logs.single.id, '${habit.id}_${dateKey(DateTime.now())}');
      final unchecked = await repo.toggleHabit(habit.id);
      expect(unchecked.logs, isEmpty);
    });

    test('dashboard numbers come from the device', () async {
      final db = await _freshDb();
      final now = DateTime(2026, 10, 15, 12);
      final tasks = TaskRepository(db);
      await tasks.createTask(_task('Due today', due: DateTime(2026, 10, 15)));
      await tasks.createTask(_task('Overdue', due: DateTime(2026, 10, 1)));
      await tasks.createTask(_task('Later', due: DateTime(2026, 11, 1)));
      final expenses = ExpenseRepository(db);
      await expenses.addTransaction({
        'amount': 500,
        'type': 'expense',
        'account': 'bkash',
        'transaction_date': '2026-10-14',
      });
      await expenses.addTransaction({
        'amount': '2000',
        'type': 'income',
        'transaction_date': '2026-10-02T09:00:00.000',
      });

      final summary = DashboardRepository(
        db,
        () => 8000,
      ).fetchSummary(now: now);
      expect(summary.tasksTotal, 2);
      expect(summary.monthlyExpenses, 500);
      expect(summary.monthlyIncome, 2000);
      expect(summary.monthlyBudget, 8000);
      expect(summary.accountBalances['bkash'], -500);
      expect(summary.accountBalances['cash'], 2000);
    });

    test('deleting a category keeps its transactions, uncategorised', () async {
      final repo = ExpenseRepository(await _freshDb());
      final food = await repo.createCategory({
        'name': 'Food',
        'type': 'expense',
      });
      final tx = await repo.addTransaction({
        'amount': 120,
        'type': 'expense',
        'category_id': food.id,
        'transaction_date': dateKey(DateTime.now()),
      });
      expect(repo.fetchSpendingByCategory().single.name, 'Food');

      await repo.deleteCategory(food.id);
      final after = repo.allTransactions().single;
      expect(after.id, tx.id);
      expect(after.category, isNull);
      expect(repo.fetchSpendingByCategory().single.name, 'Uncategorised');
    });

    test('new wishlist items go on top; reordering sticks', () async {
      final repo = WishlistRepository(await _freshDb());
      final a = await repo.createItem({'title': 'A'});
      final b = await repo.createItem({'title': 'B'});
      expect(repo.fetchWishlist().map((i) => i.title), ['B', 'A']);
      await repo.reorder([a.id, b.id]);
      expect(repo.fetchWishlist().map((i) => i.title), ['A', 'B']);
    });

    test('screens update by themselves after a change', () async {
      final db = await _freshDb();
      final container = ProviderContainer(
        overrides: [localDbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.listen(tasksProvider, (_, _) {});
      expect(container.read(tasksProvider).value, isEmpty);

      await container.read(tasksProvider.notifier).addTask(_task('New'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(tasksProvider).value!.single.title, 'New');
    });
  });

  group('sync', () {
    test('uploads edits, applies the server\'s, keeps the cursor', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 't'});
      final db = await _freshDb();
      final mine = await db.save('tasks', {
        'title': 'Made offline',
        'status': 'todo',
        'priority': 'low',
      });
      final api = ApiClient(
        StorageService(await SharedPreferences.getInstance()),
      );
      Map<String, dynamic>? sent;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent = options.data as Map<String, dynamic>;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'cursor': '2026-10-15 12:00:00',
                  'changes': {
                    'tasks': [
                      {...Map.of(mine)..remove('_dirty')},
                    ],
                    'habits': [
                      {
                        'id': 'from-web',
                        'name': 'Stretch',
                        'updated_at': '2026-10-15T05:00:00.000Z',
                        'deleted_at': null,
                      },
                    ],
                  },
                  'rejected': {},
                },
              ),
            );
          },
        ),
      );

      await SyncService(db, api).run();

      expect(sent!['since'], isNull);
      final uploaded = (sent!['changes']['tasks'] as List).single as Map;
      expect(uploaded['title'], 'Made offline');
      expect(uploaded.containsKey('_dirty'), isFalse);
      expect(db.pendingCount, 0);
      expect(db.get('habits', 'from-web')?['name'], 'Stretch');
      expect(db.meta('sync_cursor'), '2026-10-15 12:00:00');
    });
  });

  group('signing in', () {
    test('the app opens offline with the account it last saw', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 't',
        'cached_user': '{"id": 7, "name": "Akhi", "email": "a@b.c"}',
      });
      final storage = StorageService(await SharedPreferences.getInstance());
      final repo = AuthRepository(_OfflineAuth(), storage);
      final user = await repo.getUser();
      expect(user?.id, 7);
      expect(storage.getToken(), 't');
    });

    test('"without an account" is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = await _freshDb();
      ProviderContainer make() => ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localDbProvider.overrideWithValue(db),
        ],
      );

      final first = make();
      expect(await first.read(authProvider.future), isNull);
      await first.read(authProvider.notifier).useWithoutAccount();
      expect(first.read(authProvider).value?.isLocal, isTrue);
      first.dispose();

      final again = make();
      addTearDown(again.dispose);
      expect((await again.read(authProvider.future))?.isLocal, isTrue);
    });
  });
}

/// The server can't be reached.
class _OfflineAuth implements AuthDataSource {
  @override
  Future<Map<String, dynamic>> getUser() async => throw DioException(
    requestOptions: RequestOptions(path: '/user'),
    type: DioExceptionType.connectionError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
