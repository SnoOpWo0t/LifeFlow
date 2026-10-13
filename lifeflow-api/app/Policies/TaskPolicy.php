<?php

namespace App\Policies;

use App\Models\Task;
use App\Models\User;

/**
 * Users may only change or delete their own tasks. Laravel discovers this
 * policy by name, and controllers call Gate::authorize() before writes.
 */
class TaskPolicy
{
    public function update(User $user, Task $task): bool
    {
        return $user->id === $task->user_id;
    }

    public function delete(User $user, Task $task): bool
    {
        return $user->id === $task->user_id;
    }
}
