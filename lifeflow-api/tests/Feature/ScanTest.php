<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** The AI photo reader, with Gemini faked: no key, no network, no cost. */
class ScanTest extends TestCase
{
    use RefreshDatabase;

    private const IMAGE = 'aGVsbG8='; // any valid base64

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.gemini.key' => 'test-key',
            'services.gemini.models' => 'model-a,model-b',
            'services.gemini.daily_scans' => 40,
        ]);
    }

    /** A Gemini reply whose answer is [$json]. */
    private function geminiSays(array $json): array
    {
        return ['candidates' => [['content' => ['parts' => [['text' => json_encode($json)]]]]]];
    }

    private function scan(string $target = 'money')
    {
        return $this->postJson('/api/v1/scan', ['image' => self::IMAGE, 'mime_type' => 'image/jpeg', 'target' => $target]);
    }

    public function test_a_receipt_becomes_reviewable_items_in_the_users_categories(): void
    {
        $user = User::factory()->create();
        $user->expenseCategories()->create(['name' => 'Food', 'type' => 'expense']);
        Sanctum::actingAs($user);

        Http::fake(['*' => Http::response($this->geminiSays([
            'kind' => 'receipt',
            'merchant' => '  Shwapno   Gulshan ',
            'date' => '2999-01-01', // a future date is a misread
            'items' => [
                ['name' => 'Rice 5kg', 'amount' => 450, 'category' => 'food'],
                ['name' => 'Shampoo', 'amount' => 320, 'category' => 'toiletries'],
                ['name' => 'Free gift', 'amount' => 0, 'category' => 'Food'],
            ],
            'extras' => [['name' => 'VAT', 'amount' => 38.5]],
            'discount' => 20,
            'total' => 788.5,
            'entries' => [],
        ]))]);

        $this->scan()
            ->assertOk()
            ->assertJsonPath('kind', 'receipt')
            ->assertJsonPath('receipt.merchant', 'Shwapno Gulshan')
            ->assertJsonPath('receipt.date', '')
            ->assertJsonCount(2, 'receipt.items')
            ->assertJsonPath('receipt.items.0.category', 'Food') // the user's own spelling
            ->assertJsonPath('receipt.items.0.new_category', false)
            ->assertJsonPath('receipt.items.1.category', 'Toiletries')
            ->assertJsonPath('receipt.items.1.new_category', true)
            ->assertJsonPath('receipt.extras.0.amount', 38.5)
            ->assertJsonPath('receipt.discount', 20);

        // The prompt told Gemini about the user's categories, and the key stayed in a header.
        Http::assertSent(fn (Request $request) => str_contains($request->body(), 'Expense categories: Food')
            && $request->hasHeader('x-goog-api-key', 'test-key')
            && ! str_contains($request->url(), 'test-key'));
    }

    public function test_a_notes_screenshot_becomes_income_and_expense_entries(): void
    {
        Sanctum::actingAs(User::factory()->create());
        Http::fake(['*' => Http::response($this->geminiSays([
            'kind' => 'notes',
            'merchant' => '', 'date' => '', 'items' => [], 'extras' => [], 'discount' => 0, 'total' => 0,
            'entries' => [
                ['type' => 'income', 'name' => 'Salary', 'amount' => 50000, 'category' => 'Salary', 'date' => '2026-10-01'],
                ['type' => 'expense', 'name' => 'Rickshaw', 'amount' => 60, 'category' => '', 'date' => ''],
                ['type' => 'weird', 'name' => '', 'amount' => 100, 'category' => 'Snacks', 'date' => 'yesterday'],
            ],
        ]))]);

        $this->scan()
            ->assertOk()
            ->assertJsonPath('kind', 'notes')
            ->assertJsonCount(3, 'notes.entries')
            ->assertJsonPath('notes.entries.0.type', 'income')
            ->assertJsonPath('notes.entries.0.new_category', true)
            ->assertJsonPath('notes.entries.1.category', '')
            ->assertJsonPath('notes.entries.2.type', 'expense') // unknown type -> expense
            ->assertJsonPath('notes.entries.2.name', 'Snacks')   // empty name -> its category
            ->assertJsonPath('notes.entries.2.date', '');        // not a date -> ""
    }

    public function test_a_shopping_list_becomes_wishlist_items(): void
    {
        $user = User::factory()->create();
        $user->wishlistItems()->create(['title' => 'Old', 'category' => 'Electronics']);
        Sanctum::actingAs($user);
        Http::fake(['*' => Http::response($this->geminiSays([
            'isList' => true,
            'items' => [
                ['title' => 'Sony WH-1000XM5', 'note' => 'Black', 'price' => 42000, 'priority' => 'high', 'category' => 'electronics', 'link' => 'https://daraz.com.bd/x'],
                ['title' => 'Rice 5 kg', 'note' => '', 'price' => 0, 'priority' => 'urgent', 'category' => 'Groceries', 'link' => 'javascript:alert(1)'],
                ['title' => '', 'note' => '', 'price' => 10, 'priority' => 'low', 'category' => '', 'link' => ''],
            ],
        ]))]);

        $this->scan('wishlist')
            ->assertOk()
            ->assertJsonPath('kind', 'wishlist')
            ->assertJsonCount(2, 'wishlist.items')
            ->assertJsonPath('wishlist.items.0.category', 'Electronics')
            ->assertJsonPath('wishlist.items.0.link', 'https://daraz.com.bd/x')
            ->assertJsonPath('wishlist.items.1.priority', 'normal') // unknown -> normal
            ->assertJsonPath('wishlist.items.1.link', '');           // only http(s) links
    }

    public function test_photos_that_are_not_receipts_or_lists_are_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());
        Http::fake(['*' => Http::response($this->geminiSays([
            'kind' => 'other', 'merchant' => '', 'date' => '', 'items' => [], 'extras' => [],
            'discount' => 0, 'total' => 0, 'entries' => [],
        ]))]);

        $this->scan()->assertStatus(422)->assertJsonPath('message', fn ($m) => str_contains($m, "doesn't look like"));
    }

    public function test_the_next_model_is_tried_when_one_is_busy(): void
    {
        Sanctum::actingAs(User::factory()->create());
        Http::fake([
            '*model-a*' => Http::response(['error' => 'overloaded'], 503),
            '*model-b*' => Http::response($this->geminiSays(['isList' => true, 'items' => [
                ['title' => 'Lamp', 'note' => '', 'price' => 900, 'priority' => 'normal', 'category' => 'Home', 'link' => ''],
            ]])),
        ]);

        $this->scan('wishlist')->assertOk()->assertJsonPath('wishlist.items.0.title', 'Lamp');
    }

    public function test_busy_models_give_a_try_again_message(): void
    {
        Sanctum::actingAs(User::factory()->create());
        Http::fake(['*' => Http::response(['error' => 'rate limited'], 429)]);

        $this->scan()->assertStatus(503)->assertJsonPath('message', fn ($m) => str_contains($m, 'busy'));
    }

    public function test_scanning_is_off_without_a_key(): void
    {
        config(['services.gemini.key' => null]);
        Sanctum::actingAs(User::factory()->create());
        Http::fake();

        $this->scan()->assertStatus(503);
        Http::assertNothingSent();
    }

    public function test_each_user_has_a_daily_photo_limit(): void
    {
        config(['services.gemini.daily_scans' => 2]);
        Sanctum::actingAs(User::factory()->create());
        Http::fake(['*' => Http::response($this->geminiSays(['isList' => false, 'items' => []]))]);

        $this->scan('wishlist')->assertStatus(422);
        $this->scan('wishlist')->assertStatus(422);
        $this->scan('wishlist')->assertStatus(429);
    }

    public function test_bad_uploads_are_rejected_before_calling_gemini(): void
    {
        Sanctum::actingAs(User::factory()->create());
        Http::fake();

        $this->postJson('/api/v1/scan', ['image' => 'not base64!', 'mime_type' => 'image/gif', 'target' => 'tasks'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['image', 'mime_type', 'target']);
        $this->postJson('/api/v1/scan', [])->assertStatus(422);
        Http::assertNothingSent();
    }

    public function test_scanning_requires_sign_in(): void
    {
        $this->scan()->assertStatus(401);
    }
}
