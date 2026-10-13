<?php

namespace Tests\Feature;

use App\Models\Habit;
use App\Models\Task;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
        $this->assertDatabaseMissing('transactions', ['id' => $tx->id]);
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
}
