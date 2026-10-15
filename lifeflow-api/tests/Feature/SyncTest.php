<?php

namespace Tests\Feature;

use App\Models\ExpenseCategory;
use App\Models\Habit;
use App\Models\Task;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SyncTest extends TestCase
{
    use RefreshDatabase;

    private function task(string $id, string $title, string $at, array $extra = []): array
    {
        return array_merge([
            'id' => $id,
            'title' => $title,
            'status' => 'todo',
            'priority' => 'medium',
            'due_date' => '2026-10-20T09:30:00.000',
            'updated_at' => $at,
            'deleted_at' => null,
        ], $extra);
    }

    public function test_sync_requires_sign_in(): void
    {
        $this->postJson('/api/v1/sync', [])->assertUnauthorized();
    }

    public function test_records_made_offline_are_saved_and_linked_by_uuid(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/sync', [
            'since' => null,
            'changes' => [
                'categories' => [['id' => 'cat-1', 'name' => 'Food', 'type' => 'expense', 'color_hex' => '#FF0000', 'updated_at' => '2026-10-15T08:00:00Z']],
                'transactions' => [[
                    'id' => 'tx-1', 'category_id' => 'cat-1', 'amount' => 250, 'type' => 'expense',
                    'account' => 'bkash', 'transaction_date' => '2026-10-15', 'note' => 'Lunch',
                    'updated_at' => '2026-10-15T08:01:00Z',
                ]],
                'habits' => [['id' => 'habit-1', 'name' => 'Read', 'updated_at' => '2026-10-15T08:00:00Z']],
                'habit_logs' => [['id' => 'habit-1_2026-10-15', 'habit_id' => 'habit-1', 'completed_date' => '2026-10-15', 'updated_at' => '2026-10-15T08:02:00Z']],
                'tasks' => [$this->task('task-1', 'Pay rent', '2026-10-15T08:00:00Z')],
                'wishlist' => [['id' => 'wish-1', 'title' => 'Headphones', 'estimated_price' => 3500, 'updated_at' => '2026-10-15T08:00:00Z']],
            ],
        ])->assertOk()->assertJsonStructure(['cursor', 'changes' => ['tasks', 'transactions'], 'rejected']);

        $category = ExpenseCategory::where('uuid', 'cat-1')->firstOrFail();
        $tx = Transaction::where('uuid', 'tx-1')->firstOrFail();
        $this->assertSame($user->id, $tx->user_id);
        $this->assertSame($category->id, $tx->category_id);
        $this->assertSame('bkash', $tx->account);
        $this->assertSame(1, Habit::where('uuid', 'habit-1')->first()->logs()->count());

        // The reply speaks uuids, never server ids.
        $response->assertJsonPath('changes.transactions.0.category_id', 'cat-1')
            ->assertJsonPath('changes.habit_logs.0.habit_id', 'habit-1')
            ->assertJsonPath('changes.tasks.0.due_date', '2026-10-20T09:30:00')
            ->assertJsonPath('changes.wishlist.0.estimated_price', 3500);
    }

    public function test_the_newest_edit_wins(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/sync', ['changes' => ['tasks' => [$this->task('t', 'Second edit', '2026-10-15T10:00:00Z')]]])->assertOk();

        // An older offline edit arrives later: ignored, and the newer one is sent back.
        $this->postJson('/api/v1/sync', [
            'since' => now()->addHour()->toIso8601String(),
            'changes' => ['tasks' => [$this->task('t', 'First edit', '2026-10-15T09:00:00Z')]],
        ])->assertOk()
            ->assertJsonPath('changes.tasks.0.title', 'Second edit');
        $this->assertSame('Second edit', Task::where('uuid', 't')->value('title'));

        // A newer one replaces it.
        $this->postJson('/api/v1/sync', ['changes' => ['tasks' => [$this->task('t', 'Third edit', '2026-10-15T11:00:00Z')]]])->assertOk();
        $this->assertSame('Third edit', Task::where('uuid', 't')->value('title'));
    }

    public function test_deletes_travel_as_tombstones(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $task = Task::create(['user_id' => $user->id, 'title' => 'Old', 'status' => 'todo', 'priority' => 'low']);

        $first = $this->postJson('/api/v1/sync', ['since' => null])->assertOk();
        $first->assertJsonPath('changes.tasks.0.id', $task->uuid);
        $cursor = $first->json('cursor');

        Carbon::setTestNow(now()->addMinute());
        $this->deleteJson("/api/v1/tasks/{$task->id}")->assertNoContent();

        $this->postJson('/api/v1/sync', ['since' => $cursor])->assertOk()
            ->assertJsonPath('changes.tasks.0.id', $task->uuid)
            ->assertJsonPath('changes.tasks.0.deleted_at', fn ($v) => $v !== null);

        // A delete made on the phone hides it from the REST API too.
        $other = Task::create(['user_id' => $user->id, 'title' => 'Other', 'status' => 'todo', 'priority' => 'low']);
        $this->postJson('/api/v1/sync', ['changes' => ['tasks' => [
            $this->task($other->uuid, 'Other', now()->addMinute()->toIso8601String(), ['deleted_at' => now()->addMinute()->toIso8601String()]),
        ]]])->assertOk();
        $this->getJson('/api/v1/tasks')->assertOk()->assertJsonCount(0);
    }

    public function test_a_habit_check_in_is_one_row_per_day_across_devices(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = Habit::create(['user_id' => $user->id, 'name' => 'Walk']);

        // Checked on the web, then unchecked and checked again: still one row.
        $this->postJson("/api/v1/habits/{$habit->id}/toggle")->assertOk();
        $this->postJson("/api/v1/habits/{$habit->id}/toggle")->assertOk();
        $this->postJson("/api/v1/habits/{$habit->id}/toggle")->assertOk();
        $today = $user->localNow()->toDateString();
        $this->assertSame(1, $habit->logs()->withTrashed()->count());

        // The phone, offline, unchecked the same day later on.
        $this->postJson('/api/v1/sync', ['changes' => ['habit_logs' => [[
            'id' => 'whatever', 'habit_id' => $habit->uuid, 'completed_date' => $today,
            'updated_at' => now()->addMinute()->toIso8601String(), 'deleted_at' => now()->addMinute()->toIso8601String(),
        ]]]])->assertOk();

        $this->assertSame(0, $habit->logs()->count());
        $this->assertSame(1, $habit->logs()->withTrashed()->count());
        $this->assertSame($habit->uuid.'_'.$today, $habit->logs()->withTrashed()->value('uuid'));
    }

    public function test_other_users_records_and_bad_records_are_rejected(): void
    {
        $owner = User::factory()->create();
        $task = Task::create(['user_id' => $owner->id, 'title' => 'Mine', 'status' => 'todo', 'priority' => 'low']);
        $category = ExpenseCategory::create(['user_id' => $owner->id, 'name' => 'Private', 'type' => 'expense']);

        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/v1/sync', ['changes' => [
            'tasks' => [
                $this->task($task->uuid, 'Hijacked', now()->addDay()->toIso8601String()),
                ['id' => 'no-title', 'status' => 'todo', 'priority' => 'low', 'updated_at' => now()->toIso8601String()],
            ],
            'transactions' => [[
                'id' => 'tx', 'category_id' => $category->uuid, 'amount' => 10, 'type' => 'expense',
                'transaction_date' => '2026-10-15', 'updated_at' => now()->toIso8601String(),
            ]],
        ]])->assertOk()
            ->assertJsonPath('rejected.tasks', [$task->uuid, 'no-title'])
            ->assertJsonCount(1, 'changes.transactions')
            ->assertJsonCount(0, 'changes.tasks');

        $this->assertSame('Mine', $task->fresh()->title);
        $this->assertNull(Transaction::where('uuid', 'tx')->value('category_id'));
    }

    public function test_rest_edits_get_uuids_and_show_up_in_the_next_sync(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $cursor = $this->postJson('/api/v1/sync', [])->json('cursor');

        Carbon::setTestNow(now()->addMinute());
        $this->postJson('/api/v1/tasks', ['title' => 'From the web', 'status' => 'todo', 'priority' => 'high'])->assertCreated();

        $this->postJson('/api/v1/sync', ['since' => $cursor])->assertOk()
            ->assertJsonPath('changes.tasks.0.title', 'From the web')
            ->assertJsonPath('changes.tasks.0.id', fn ($id) => is_string($id) && strlen($id) === 36);
    }
}
