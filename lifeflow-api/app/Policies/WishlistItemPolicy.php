<?php

namespace App\Policies;

use App\Models\User;
use App\Models\WishlistItem;

class WishlistItemPolicy
{
    public function update(User $user, WishlistItem $item): bool
    {
        return $user->id === $item->user_id;
    }

    public function delete(User $user, WishlistItem $item): bool
    {
        return $user->id === $item->user_id;
    }
}
