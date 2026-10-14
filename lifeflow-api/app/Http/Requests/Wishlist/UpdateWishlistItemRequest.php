<?php

namespace App\Http\Requests\Wishlist;

/** Same rules as creating, but every field is optional. */
class UpdateWishlistItemRequest extends StoreWishlistItemRequest
{
    public function rules(): array
    {
        return array_map(
            fn ($rule) => array_merge(['sometimes'], (array) $rule),
            parent::rules(),
        );
    }
}
