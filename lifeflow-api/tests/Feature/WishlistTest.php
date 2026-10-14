<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WishlistItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WishlistTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_list_their_wishlist_items(): void
    {
        $user1 = User::factory()->create();
        $user2 = User::factory()->create();

        WishlistItem::create([
            'user_id' => $user1->id,
            'title' => 'Mechanical Keyboard',
            'estimated_price' => 120.00,
            'priority' => 'high',
        ]);
        WishlistItem::create([
            'user_id' => $user2->id,
            'title' => 'Secret Item',
            'estimated_price' => 50.00,
        ]);

        Sanctum::actingAs($user1);

        $response = $this->getJson('/api/v1/wishlist');

        $response->assertOk();
        $response->assertJsonCount(1);
        $response->assertJsonFragment(['title' => 'Mechanical Keyboard']);
        $response->assertJsonMissing(['title' => 'Secret Item']);
    }

    public function test_user_can_create_wishlist_item(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/wishlist', [
            'title' => 'Noise Cancelling Headphones',
            'note' => 'Sony WH-1000XM5 in silver',
            'estimated_price' => 349.99,
            'priority' => 'high',
            'link' => 'https://example.com/headphones',
        ]);

        $response->assertCreated();
        $response->assertJsonFragment([
            'title' => 'Noise Cancelling Headphones',
            'priority' => 'high',
            'is_purchased' => false,
        ]);

        $this->assertDatabaseHas('wishlist_items', [
            'user_id' => $user->id,
            'title' => 'Noise Cancelling Headphones',
        ]);
    }

    public function test_create_wishlist_item_validation(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/wishlist', [
            'title' => '',
            'priority' => 'invalid_priority',
            'estimated_price' => -10,
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['title', 'priority', 'estimated_price']);
    }

    public function test_user_can_view_single_wishlist_item(): void
    {
        $user = User::factory()->create();
        $item = WishlistItem::create([
            'user_id' => $user->id,
            'title' => 'Ergonomic Desk Chair',
            'estimated_price' => 250.00,
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson("/api/v1/wishlist/{$item->id}");

        $response->assertOk();
        $response->assertJsonFragment(['title' => 'Ergonomic Desk Chair']);
    }

    public function test_user_can_update_wishlist_item(): void
    {
        $user = User::factory()->create();
        $item = WishlistItem::create([
            'user_id' => $user->id,
            'title' => 'Smart Watch',
            'is_purchased' => false,
            'estimated_price' => 200.00,
        ]);

        Sanctum::actingAs($user);

        $response = $this->putJson("/api/v1/wishlist/{$item->id}", [
            'is_purchased' => true,
            'estimated_price' => 180.00,
        ]);

        $response->assertOk();
        $response->assertJsonFragment([
            'is_purchased' => true,
            'estimated_price' => '180.00',
        ]);

        $this->assertTrue($item->fresh()->is_purchased);
    }

    public function test_user_can_delete_wishlist_item(): void
    {
        $user = User::factory()->create();
        $item = WishlistItem::create([
            'user_id' => $user->id,
            'title' => 'Old Book',
        ]);

        Sanctum::actingAs($user);

        $response = $this->deleteJson("/api/v1/wishlist/{$item->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('wishlist_items', ['id' => $item->id]);
    }

    public function test_user_cannot_access_or_modify_another_users_wishlist_item(): void
    {
        $user1 = User::factory()->create();
        $user2 = User::factory()->create();

        $item = WishlistItem::create([
            'user_id' => $user1->id,
            'title' => 'Private Item',
        ]);

        Sanctum::actingAs($user2);

        $this->getJson("/api/v1/wishlist/{$item->id}")->assertForbidden();

        $this->putJson("/api/v1/wishlist/{$item->id}", [
            'title' => 'Hacked Item',
        ])->assertForbidden();

        $this->deleteJson("/api/v1/wishlist/{$item->id}")->assertForbidden();

        $this->assertEquals('Private Item', $item->fresh()->title);
    }

    public function test_user_can_reorder_wishlist_items(): void
    {
        $user = User::factory()->create();
        $item1 = WishlistItem::create(['user_id' => $user->id, 'title' => 'Item 1', 'sort_order' => 0]);
        $item2 = WishlistItem::create(['user_id' => $user->id, 'title' => 'Item 2', 'sort_order' => 1]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/wishlist/reorder', [
            'order' => [$item2->id, $item1->id],
        ]);

        $response->assertOk();
        $this->assertEquals(0, $item2->fresh()->sort_order);
        $this->assertEquals(1, $item1->fresh()->sort_order);
    }

    public function test_wishlist_items_included_in_data_export(): void
    {
        $user = User::factory()->create();
        WishlistItem::create([
            'user_id' => $user->id,
            'title' => 'Coffee Machine',
            'estimated_price' => 99.00,
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/profile/export?format=json');

        $response->assertOk();
        $response->assertJsonFragment(['title' => 'Coffee Machine']);
    }

    public function test_wishlist_items_cascade_delete_with_user(): void
    {
        $user = User::factory()->create();
        $item = WishlistItem::create([
            'user_id' => $user->id,
            'title' => 'Coffee Machine',
        ]);

        $user->delete();

        $this->assertDatabaseMissing('wishlist_items', ['id' => $item->id]);
    }

    public function test_user_can_create_and_filter_by_custom_category(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Create a Perfume item
        $perfume = $this->postJson('/api/v1/wishlist', [
            'title' => 'Dior Sauvage Elixir',
            'estimated_price' => 160.00,
            'priority' => 'high',
            'category' => 'Perfume',
        ]);
        $perfume->assertCreated();
        $perfume->assertJsonFragment(['category' => 'Perfume']);

        // Create a Tech item
        $tech = $this->postJson('/api/v1/wishlist', [
            'title' => 'iPad Air M2',
            'estimated_price' => 599.00,
            'category' => 'Tech',
        ]);
        $tech->assertCreated();
        $tech->assertJsonFragment(['category' => 'Tech']);

        // Filter by Perfume
        $perfumeList = $this->getJson('/api/v1/wishlist?category=Perfume');
        $perfumeList->assertOk();
        $perfumeList->assertJsonCount(1);
        $perfumeList->assertJsonFragment(['title' => 'Dior Sauvage Elixir']);
        $perfumeList->assertJsonMissing(['title' => 'iPad Air M2']);

        // Filter by Tech
        $techList = $this->getJson('/api/v1/wishlist?category=Tech');
        $techList->assertOk();
        $techList->assertJsonCount(1);
        $techList->assertJsonFragment(['title' => 'iPad Air M2']);
        $techList->assertJsonMissing(['title' => 'Dior Sauvage Elixir']);
    }

    public function test_user_can_update_item_category(): void
    {
        $user = User::factory()->create();
        $item = WishlistItem::create([
            'user_id' => $user->id,
            'title' => 'Desk Mat',
            'category' => 'Office',
        ]);

        Sanctum::actingAs($user);

        $response = $this->putJson("/api/v1/wishlist/{$item->id}", [
            'category' => 'Tech',
        ]);

        $response->assertOk();
        $response->assertJsonFragment(['category' => 'Tech']);
        $this->assertEquals('Tech', $item->fresh()->category);
    }
}
