<?php

namespace App\Policies;

use App\Models\ExpenseCategory;
use App\Models\User;

/**
 * Users may only change or delete their own categories. Laravel discovers this
 * policy by name, and controllers call Gate::authorize() before writes.
 */
class ExpenseCategoryPolicy
{
    public function update(User $user, ExpenseCategory $category): bool
    {
        return $user->id === $category->user_id;
    }

    public function delete(User $user, ExpenseCategory $category): bool
    {
        return $user->id === $category->user_id;
    }
}
