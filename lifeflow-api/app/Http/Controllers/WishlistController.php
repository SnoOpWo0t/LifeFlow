<?php

namespace App\Http\Controllers;

use App\Http\Requests\Wishlist\ReorderWishlistRequest;
use App\Http\Requests\Wishlist\StoreWishlistItemRequest;
use App\Http\Requests\Wishlist\UpdateWishlistItemRequest;
use App\Http\Resources\WishlistItemResource;
use App\Models\WishlistItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class WishlistController extends Controller
{
    /** All items, unpurchased first, then by sort_order. */
    public function index(Request $request): AnonymousResourceCollection
    {
        $query = WishlistItem::where('user_id', $request->user()->id);

        if ($request->filled('category')) {
            $query->where('category', $request->query('category'));
        }

        $items = $query
            ->orderBy('is_purchased')
            ->orderBy('sort_order')
            ->orderBy('created_at', 'desc')
            ->get();

        return WishlistItemResource::collection($items);
    }

    public function show(WishlistItem $wishlistItem): WishlistItemResource
    {
        Gate::authorize('update', $wishlistItem);

        return new WishlistItemResource($wishlistItem);
    }

    public function store(StoreWishlistItemRequest $request): JsonResponse
    {
        // New items go to the top of the list (lowest sort_order), matching
        // where the app shows them straight after adding.
        $minSort = WishlistItem::where('user_id', $request->user()->id)->min('sort_order');

        $item = WishlistItem::create(array_merge(
            $request->validated(),
            [
                'user_id' => $request->user()->id,
                'sort_order' => $request->input('sort_order', $minSort === null ? 0 : $minSort - 1),
            ],
        ));

        return (new WishlistItemResource($item))->response()->setStatusCode(201);
    }

    public function update(UpdateWishlistItemRequest $request, WishlistItem $wishlistItem): WishlistItemResource
    {
        Gate::authorize('update', $wishlistItem);

        $wishlistItem->update($request->validated());

        return new WishlistItemResource($wishlistItem);
    }

    public function destroy(WishlistItem $wishlistItem): JsonResponse
    {
        Gate::authorize('delete', $wishlistItem);

        $wishlistItem->delete();

        return response()->json(null, 204);
    }

    /** Bulk-reorder: accepts { "order": [3, 1, 5, 2, ...] } (item IDs). */
    public function reorder(ReorderWishlistRequest $request): JsonResponse
    {
        $userId = $request->user()->id;
        foreach ($request->input('order') as $index => $id) {
            WishlistItem::where('id', $id)->where('user_id', $userId)->update(['sort_order' => $index]);
        }

        return response()->json(['message' => 'Reordered']);
    }
}
