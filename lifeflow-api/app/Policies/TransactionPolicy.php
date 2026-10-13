<?php

namespace App\Policies;

use App\Models\Transaction;
use App\Models\User;

/**
 * Users may only change or delete their own transactions. Laravel discovers this
 * policy by name, and controllers call Gate::authorize() before writes.
 */
class TransactionPolicy
{
    public function update(User $user, Transaction $transaction): bool
    {
        return $user->id === $transaction->user_id;
    }

    public function delete(User $user, Transaction $transaction): bool
    {
        return $user->id === $transaction->user_id;
    }
}
