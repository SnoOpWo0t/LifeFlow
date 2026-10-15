<?php

namespace Tests\Feature;

use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** AI summaries, with Gemini faked: no key, no network, no cost. */
class InsightTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.gemini.key' => 'test-key', 'services.gemini.models' => 'model-a', 'services.gemini.daily_summaries' => 20]);
    }

    private function fakeGemini(array $answer = []): void
    {
        $answer += [
            'headline' => '  You spent less than last month  ',
            'summary' => 'Spending so far is ৳1,500, mostly on Food.',
            'highlights' => ['Food is your top category', '', 'Morning run streak: 3 days'],
            'suggestions' => [
                ['title' => 'Cook at home twice', 'detail' => 'It would cut Food spending.', 'area' => 'money'],
                ['title' => 'Clear overdue tasks', 'detail' => 'Two are overdue.', 'area' => 'nonsense'],
                ['title' => '', 'detail' => 'dropped', 'area' => 'tasks'],
            ],
        ];
        Http::fake(['*' => Http::response(['candidates' => [['content' => ['parts' => [['text' => json_encode($answer)]]]]]])]);
    }

    public function test_a_summary_is_written_from_the_users_own_data_and_saved(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $food = $user->expenseCategories()->create(['name' => 'Food', 'type' => 'expense']);
        Transaction::create(['user_id' => $user->id, 'category_id' => $food->id, 'amount' => 1500, 'type' => 'expense',
            'transaction_date' => '2026-03-10', 'note' => 'Groceries']);
        Transaction::create(['user_id' => $other->id, 'amount' => 99999, 'type' => 'expense',
            'transaction_date' => '2026-03-10', 'note' => 'Someone else']);
        Sanctum::actingAs($user);
        $this->fakeGemini();

        $this->postJson('/api/v1/insights', ['period' => 'month', 'date' => '2026-03-15'])
            ->assertOk()
            ->assertJsonPath('from', '2026-03-01')
            ->assertJsonPath('to', '2026-03-31')
            ->assertJsonPath('insight.headline', 'You spent less than last month')
            ->assertJsonCount(2, 'insight.highlights')          // empty one dropped
            ->assertJsonCount(2, 'insight.suggestions')         // untitled one dropped
            ->assertJsonPath('insight.suggestions.1.area', 'money') // unknown area -> money
            ->assertJsonPath('stale', false);

        // The digest held this user's numbers only.
        Http::assertSent(fn (Request $r) => str_contains($r->body(), 'Groceries')
            && ! str_contains($r->body(), 'Someone else')
            && str_contains($r->body(), '1500'));

        // Shown again later without another AI call.
        Http::fake();
        $this->getJson('/api/v1/insights?period=month&date=2026-03-20')
            ->assertOk()
            ->assertJsonPath('insight.headline', 'You spent less than last month');
        Http::assertNothingSent();
    }

    public function test_new_data_marks_a_summary_as_out_of_date(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->fakeGemini();
        $this->postJson('/api/v1/insights', ['period' => 'week', 'date' => '2026-03-11'])->assertOk();

        $this->travel(5)->minutes();
        Transaction::create(['user_id' => $user->id, 'amount' => 50, 'type' => 'expense', 'transaction_date' => '2026-03-12']);

        $this->getJson('/api/v1/insights?period=week&date=2026-03-11')
            ->assertOk()
            ->assertJsonPath('from', '2026-03-09') // weeks start on Monday
            ->assertJsonPath('stale', true);
    }

    public function test_no_summary_yet_returns_null_without_calling_the_ai(): void
    {
        Sanctum::actingAs(User::factory()->create());
        Http::fake();

        $this->getJson('/api/v1/insights?period=month')
            ->assertOk()
            ->assertJsonPath('insight', null)
            ->assertJsonPath('configured', true);
        Http::assertNothingSent();
    }

    public function test_generating_needs_a_key_and_respects_the_daily_limit(): void
    {
        Sanctum::actingAs(User::factory()->create());

        config(['services.gemini.key' => null]);
        $this->postJson('/api/v1/insights', ['period' => 'week'])->assertStatus(503);
        $this->getJson('/api/v1/insights?period=week')->assertOk()->assertJsonPath('configured', false);

        config(['services.gemini.key' => 'test-key', 'services.gemini.daily_summaries' => 1]);
        $this->fakeGemini();
        $this->postJson('/api/v1/insights', ['period' => 'week'])->assertOk();
        $this->postJson('/api/v1/insights', ['period' => 'week'])->assertStatus(429);
    }

    public function test_summaries_are_private_and_validated(): void
    {
        $this->getJson('/api/v1/insights?period=week')->assertStatus(401);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/v1/insights?period=year')->assertStatus(422);
        $this->postJson('/api/v1/insights', ['period' => 'week', 'date' => 'soon'])->assertStatus(422);
    }
}
