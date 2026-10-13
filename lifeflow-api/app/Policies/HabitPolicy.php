<?php

namespace App\Policies;

use App\Models\Habit;
use App\Models\User;

/**
 * Users may only change or delete their own habits. Laravel discovers this
 * policy by name, and controllers call Gate::authorize() before writes.
 */
class HabitPolicy
{
    public function update(User $user, Habit $habit): bool
    {
        return $user->id === $habit->user_id;
    }

    public function delete(User $user, Habit $habit): bool
    {
        return $user->id === $habit->user_id;
    }
}
