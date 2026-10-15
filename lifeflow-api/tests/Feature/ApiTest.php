<?php

namespace Tests\Feature;

use App\Models\Habit;
use App\Models\Task;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_returns_token_and_user(): void
    {
        $response = $this->postJson('/api/v1/register', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['access_token', 'user' => ['id', 'name', 'email']]);
        $this->assertDatabaseHas('users', ['email' => 'test@example.com']);
    }

    public function test_register_validates_input(): void
    {
        $this->postJson('/api/v1/register', [
            'name' => '',
            'email' => 'not-an-email',
            'password' => 'short',
            'password_confirmation' => 'short',
        ])->assertStatus(422)->assertJsonValidationErrors(['name', 'email', 'password']);
    }

    public function test_login_rejects_wrong_password(): void
    {
        User::factory()->create(['email' => 'a@example.com', 'password' => 'correct-password']);

        $this->postJson('/api/v1/login', [
            'email' => 'a@example.com',
            'password' => 'wrong-password',
        ])->assertStatus(401);
    }

    public function test_login_is_rate_limited(): void
    {
        for ($i = 0; $i < 10; $i++) {
            $this->postJson('/api/v1/login', ['email' => 'x@example.com', 'password' => 'nope']);
        }

        $this->postJson('/api/v1/login', ['email' => 'x@example.com', 'password' => 'nope'])
            ->assertStatus(429);
    }

    public function test_logout_revokes_the_token(): void
    {
        $token = $this->postJson('/api/v1/register', [
            'name' => 'Leaving Soon',
            'email' => 'leaving@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->json('access_token');
        $auth = ['Authorization' => "Bearer {$token}"];

        $this->postJson('/api/v1/logout', [], $auth)->assertOk();
        $this->app['auth']->forgetGuards(); // don't reuse the user resolved in the previous request

        $this->getJson('/api/v1/user', $auth)->assertStatus(401);
    }

    public function test_protected_routes_require_a_token(): void
    {
        $this->getJson('/api/v1/user')->assertStatus(401);
        $this->getJson('/api/v1/tasks')->assertStatus(401);
    }

    public function test_users_only_see_their_own_tasks(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $bob->tasks()->create(['title' => "Bob's task", 'status' => 'todo', 'priority' => 'low']);

        Sanctum::actingAs($alice);
        $this->postJson('/api/v1/tasks', [
            'title' => "Alice's task",
            'status' => 'todo',
            'priority' => 'high',
        ])->assertCreated();

        $this->getJson('/api/v1/tasks')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.title', "Alice's task");
    }

    public function test_users_cannot_modify_someone_elses_task(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $task = $bob->tasks()->create(['title' => 'Private', 'status' => 'todo', 'priority' => 'low']);

        Sanctum::actingAs($alice);
        $this->putJson("/api/v1/tasks/{$task->id}", ['status' => 'done'])->assertForbidden();
        $this->deleteJson("/api/v1/tasks/{$task->id}")->assertForbidden();

        $this->assertDatabaseHas('tasks', ['id' => $task->id, 'status' => 'todo']);
    }

    public function test_habit_toggle_checks_and_unchecks_today(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $habitId = $this->postJson('/api/v1/habits', ['name' => 'Read'])
            ->assertCreated()
            ->json('id');

        $this->postJson("/api/v1/habits/{$habitId}/toggle")->assertOk();
        $habit = Habit::find($habitId);
        $this->assertSame(1, $habit->current_streak);
        $this->assertSame(1, $habit->logs()->count());

        $this->postJson("/api/v1/habits/{$habitId}/toggle")->assertOk();
        $habit->refresh();
        $this->assertSame(0, $habit->current_streak);
        $this->assertSame(0, $habit->logs()->count());
    }

    public function test_settings_are_saved_and_merged(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->putJson('/api/v1/profile/settings', ['preferences' => ['is_dark_mode' => true]])->assertOk();
        $this->putJson('/api/v1/profile/settings', ['preferences' => ['monthly_budget' => 5000]])->assertOk();

        $this->assertSame(
            ['is_dark_mode' => true, 'monthly_budget' => 5000],
            $user->fresh()->preferences,
        );
    }

    public function test_streaks_are_derived_from_check_in_history(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = $user->habits()->create(['name' => 'Run']);
        $day = fn (int $daysAgo) => now()->subDays($daysAgo)->toDateString();

        // Checked yesterday and the day before: streak is alive until tonight.
        $habit->logs()->create(['completed_date' => $day(1)]);
        $habit->logs()->create(['completed_date' => $day(2)]);
        $this->getJson('/api/v1/habits')->assertOk()->assertJsonPath('0.current_streak', 2);

        $this->postJson("/api/v1/habits/{$habit->id}/toggle")->assertOk()->assertJsonPath('current_streak', 3);

        // Unchecking today goes back to 2, not to a drifted counter.
        $this->postJson("/api/v1/habits/{$habit->id}/toggle")->assertOk()->assertJsonPath('current_streak', 2);
    }

    public function test_missed_days_reset_the_current_streak_but_keep_the_longest(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = $user->habits()->create(['name' => 'Read', 'current_streak' => 5, 'longest_streak' => 5]);
        foreach ([6, 5, 4] as $daysAgo) {
            $habit->logs()->create(['completed_date' => now()->subDays($daysAgo)->toDateString()]);
        }

        $this->getJson('/api/v1/habits')
            ->assertOk()
            ->assertJsonPath('0.current_streak', 0)
            ->assertJsonPath('0.longest_streak', 3);
    }

    public function test_habits_can_be_renamed_by_their_owner_only(): void
    {
        $owner = User::factory()->create();
        $habit = $owner->habits()->create(['name' => 'Old name']);

        Sanctum::actingAs(User::factory()->create());
        $this->putJson("/api/v1/habits/{$habit->id}", ['name' => 'Hijacked'])->assertForbidden();

        Sanctum::actingAs($owner);
        $this->putJson("/api/v1/habits/{$habit->id}", ['name' => 'New name'])
            ->assertOk()
            ->assertJsonPath('name', 'New name');
    }

    public function test_transactions_can_be_edited_and_deleted_by_their_owner_only(): void
    {
        $owner = User::factory()->create();
        $tx = Transaction::create([
            'user_id' => $owner->id, 'amount' => 100, 'type' => 'expense',
            'transaction_date' => now()->toDateString(), 'note' => 'Lunch',
        ]);

        Sanctum::actingAs(User::factory()->create());
        $this->putJson("/api/v1/transactions/{$tx->id}", ['amount' => 1])->assertForbidden();
        $this->deleteJson("/api/v1/transactions/{$tx->id}")->assertForbidden();

        Sanctum::actingAs($owner);
        $this->putJson("/api/v1/transactions/{$tx->id}", ['amount' => 250, 'note' => 'Dinner'])
            ->assertOk()
            ->assertJsonPath('note', 'Dinner');
        $this->assertEquals(250, $tx->fresh()->amount);

        $this->deleteJson("/api/v1/transactions/{$tx->id}")->assertNoContent();
        $this->assertSoftDeleted('transactions', ['id' => $tx->id]);
    }

    public function test_transactions_cannot_use_another_users_category(): void
    {
        $other = User::factory()->create();
        $foreignCategory = $other->expenseCategories()->create(['name' => 'Secret', 'type' => 'expense']);

        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/v1/transactions', [
            'category_id' => $foreignCategory->id,
            'amount' => 10,
            'type' => 'expense',
            'transaction_date' => now()->toDateString(),
        ])->assertStatus(422)->assertJsonValidationErrors(['category_id']);
    }

    public function test_dashboard_works_with_tasks_but_no_transactions(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $user->tasks()->create(['title' => 'Done', 'status' => 'done', 'priority' => 'low']);

        $this->getJson('/api/v1/dashboard/summary')
            ->assertOk()
            ->assertJsonPath('recent_activity.0.title', 'Done');
    }

    public function test_dashboard_counts_only_todays_tasks(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $make = fn (string $status, ?string $due) => $user->tasks()->create([
            'title' => 'T', 'status' => $status, 'priority' => 'low', 'due_date' => $due,
        ]);

        $make('todo', now()->toDateString());               // due today: counts
        $make('done', now()->toDateString());               // done today: counts, completed
        $make('todo', now()->subDays(3)->toDateString());   // overdue: counts
        $make('todo', now()->addDays(5)->toDateString());   // future: ignored
        $make('todo', null);                                 // no due date: ignored

        $this->getJson('/api/v1/dashboard/summary')
            ->assertOk()
            ->assertJsonPath('tasks_today.total', 3)
            ->assertJsonPath('tasks_today.completed', 1);
    }

    public function test_categories_can_be_edited_and_deleted_by_their_owner_only(): void
    {
        $owner = User::factory()->create();
        $category = $owner->expenseCategories()->create(['name' => 'Food', 'type' => 'expense']);
        $tx = Transaction::create([
            'user_id' => $owner->id, 'category_id' => $category->id, 'amount' => 50,
            'type' => 'expense', 'transaction_date' => now()->toDateString(),
        ]);

        Sanctum::actingAs(User::factory()->create());
        $this->putJson("/api/v1/categories/{$category->id}", ['name' => 'Mine now'])->assertForbidden();
        $this->deleteJson("/api/v1/categories/{$category->id}")->assertForbidden();

        Sanctum::actingAs($owner);
        $this->putJson("/api/v1/categories/{$category->id}", ['name' => 'Groceries', 'color_hex' => '#22C55E'])
            ->assertOk()
            ->assertJsonPath('name', 'Groceries')
            ->assertJsonPath('color_hex', '#22C55E');

        $this->deleteJson("/api/v1/categories/{$category->id}")->assertNoContent();
        // The transaction survives without a category.
        $this->assertDatabaseHas('transactions', ['id' => $tx->id, 'category_id' => null]);
    }

    public function test_account_deletion_requires_the_password_and_removes_all_data(): void
    {
        $user = User::factory()->create(['password' => 'correct-password']);
        $user->tasks()->create(['title' => 'Mine', 'status' => 'todo', 'priority' => 'low']);
        $user->habits()->create(['name' => 'Read']);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/profile', ['password' => 'wrong'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
        $this->assertDatabaseHas('users', ['id' => $user->id]);

        $this->deleteJson('/api/v1/profile', ['password' => 'correct-password'])->assertNoContent();
        $this->assertDatabaseMissing('users', ['id' => $user->id]);
        $this->assertDatabaseMissing('tasks', ['user_id' => $user->id]);
        $this->assertDatabaseMissing('habits', ['user_id' => $user->id]);
    }

    public function test_the_app_timezone_decides_what_today_is(): void
    {
        // UTC+14: when it's still "yesterday" on the server, it's already tomorrow here.
        $user = User::factory()->create();
        $habit = $user->habits()->create(['name' => 'Read']);
        Sanctum::actingAs($user);

        $this->withHeader('X-Timezone', 'Pacific/Kiritimati')
            ->postJson("/api/v1/habits/{$habit->id}/toggle")
            ->assertOk()
            ->assertJsonPath('logs.0.completed_date', now('Pacific/Kiritimati')->toDateString());

        $this->assertSame('Pacific/Kiritimati', $user->fresh()->timezone);
    }

    public function test_invalid_timezones_are_ignored(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->withHeader('X-Timezone', 'Not/AZone')->getJson('/api/v1/user')->assertOk();

        $this->assertNull($user->fresh()->timezone);
    }

    public function test_user_responses_do_not_leak_internal_fields(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $json = $this->getJson('/api/v1/user')->assertOk()->json();

        $this->assertSame(
            ['id', 'name', 'email', 'avatar_url', 'preferences', 'timezone', 'created_at'],
            array_keys($json),
        );
    }

    public function test_tasks_can_be_fetched_individually_by_their_owner_only(): void
    {
        $owner = User::factory()->create();
        $task = $owner->tasks()->create(['title' => 'Mine', 'status' => 'todo', 'priority' => 'low']);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/v1/tasks/{$task->id}")->assertForbidden();

        Sanctum::actingAs($owner);
        $this->getJson("/api/v1/tasks/{$task->id}")->assertOk()->assertJsonPath('title', 'Mine');
    }

    public function test_transactions_are_paginated(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        foreach (range(1, 35) as $i) {
            Transaction::create([
                'user_id' => $user->id, 'amount' => $i, 'type' => 'expense',
                'transaction_date' => now()->subDays($i)->toDateString(),
            ]);
        }

        $this->getJson('/api/v1/transactions')
            ->assertOk()
            ->assertJsonCount(30, 'data')
            ->assertJsonPath('meta.last_page', 2);

        $this->getJson('/api/v1/transactions?page=2')->assertOk()->assertJsonCount(5, 'data');
    }

    public function test_spending_by_category_covers_this_month_only(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $food = $user->expenseCategories()->create(['name' => 'Food', 'type' => 'expense', 'color_hex' => '#F97316']);
        $add = fn ($amount, $date, $category = null) => Transaction::create([
            'user_id' => $user->id, 'category_id' => $category?->id, 'amount' => $amount,
            'type' => 'expense', 'transaction_date' => $date,
        ]);
        $add(100, now()->startOfMonth()->toDateString(), $food);
        $add(50, now()->toDateString(), $food);
        $add(20, now()->toDateString());
        $add(999, now()->subMonthNoOverflow()->startOfMonth()->toDateString(), $food); // last month

        $this->getJson('/api/v1/transactions/by-category')
            ->assertOk()
            ->assertJsonPath('categories.0.name', 'Food')
            ->assertJsonPath('categories.0.total', 150)
            ->assertJsonPath('categories.1.name', 'Uncategorised');
    }

    public function test_data_export_includes_everything_and_offers_csv(): void
    {
        $user = User::factory()->create();
        $user->tasks()->create(['title' => 'Export me', 'status' => 'todo', 'priority' => 'low']);
        Transaction::create([
            'user_id' => $user->id, 'amount' => 42, 'type' => 'income',
            'transaction_date' => now()->toDateString(), 'note' => 'Gift',
        ]);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/profile/export')
            ->assertOk()
            ->assertHeader('Content-Disposition')
            ->assertJsonPath('profile.email', $user->email)
            ->assertJsonPath('tasks.0.title', 'Export me')
            ->assertJsonPath('transactions.0.note', 'Gift');

        $csv = $this->get('/api/v1/profile/export?format=csv')->assertOk()->streamedContent();
        $this->assertStringStartsWith('date,type,amount,category,note', $csv);
        $this->assertStringContainsString('income,42', $csv);
    }

    public function test_avatars_are_only_served_through_signed_links(): void
    {
        Storage::fake('public');
        Storage::disk('public')->put('avatars/me.png', 'fake-image-bytes');
        $user = User::factory()->create();
        $user->forceFill(['avatar_path' => 'me.png'])->save();
        Sanctum::actingAs($user);

        $signedUrl = $this->getJson('/api/v1/user')->json('avatar_url');
        $this->assertStringContainsString('signature=', $signedUrl);

        $this->get($signedUrl)->assertOk();
        $this->get('/api/v1/avatar/me.png')->assertForbidden(); // no signature
    }

    public function test_calendar_month_summarises_each_day(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = $user->habits()->create(['name' => 'Run']);
        $user->habits()->create(['name' => 'Read']);

        $user->tasks()->create(['title' => 'A', 'status' => 'done', 'priority' => 'low', 'due_date' => '2026-03-10']);
        $user->tasks()->create(['title' => 'B', 'status' => 'todo', 'priority' => 'low', 'due_date' => '2026-03-10']);
        $user->tasks()->create(['title' => 'Next month', 'status' => 'todo', 'priority' => 'low', 'due_date' => '2026-04-01']);
        $habit->logs()->create(['completed_date' => '2026-03-10']);
        Transaction::create(['user_id' => $user->id, 'amount' => 300, 'type' => 'expense', 'transaction_date' => '2026-03-12']);
        Transaction::create(['user_id' => $user->id, 'amount' => 900, 'type' => 'income', 'transaction_date' => '2026-03-12']);

        $this->getJson('/api/v1/calendar?month=2026-03')
            ->assertOk()
            ->assertJsonPath('month', '2026-03')
            ->assertJsonPath('habits_total', 2)
            ->assertJsonCount(2, 'days')
            ->assertJsonPath('days.0.date', '2026-03-10')
            ->assertJsonPath('days.0.tasks_due', 2)
            ->assertJsonPath('days.0.tasks_done', 1)
            ->assertJsonPath('days.0.habits_done', 1)
            ->assertJsonPath('days.1.date', '2026-03-12')
            ->assertJsonPath('days.1.spent', 300)
            ->assertJsonPath('days.1.earned', 900);
    }

    public function test_calendar_day_lists_only_your_own_things(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $habit = $user->habits()->create(['name' => 'Run']);
        $habit->logs()->create(['completed_date' => '2026-03-10']);
        $user->tasks()->create(['title' => 'Mine', 'status' => 'todo', 'priority' => 'low', 'due_date' => '2026-03-10']);
        $other->tasks()->create(['title' => 'Not mine', 'status' => 'todo', 'priority' => 'low', 'due_date' => '2026-03-10']);
        Transaction::create(['user_id' => $other->id, 'amount' => 5, 'type' => 'expense', 'transaction_date' => '2026-03-10']);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/calendar/day?date=2026-03-10')
            ->assertOk()
            ->assertJsonCount(1, 'tasks')
            ->assertJsonPath('tasks.0.title', 'Mine')
            ->assertJsonPath('habits.0.done', true)
            ->assertJsonCount(0, 'transactions');
    }

    public function test_calendar_rejects_malformed_months(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/calendar?month=March')->assertStatus(422);
        $this->getJson('/api/v1/calendar/day')->assertStatus(422);
    }

    public function test_transactions_default_to_cash_when_account_is_missing_or_null(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $base = ['amount' => 5, 'type' => 'expense', 'transaction_date' => '2026-10-14'];

        $this->postJson('/api/v1/transactions', $base + ['account' => null])
            ->assertCreated()
            ->assertJsonPath('account', 'cash');
        $this->postJson('/api/v1/transactions', $base)->assertCreated()->assertJsonPath('account', 'cash');
        $this->postJson('/api/v1/transactions', $base + ['account' => 'bkash'])->assertJsonPath('account', 'bkash');
        $this->postJson('/api/v1/transactions', $base + ['account' => 'paypal'])->assertStatus(422);
    }
}
