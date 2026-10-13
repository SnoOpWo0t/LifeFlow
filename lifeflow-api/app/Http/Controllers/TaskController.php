<?php

namespace App\Http\Controllers;

use App\Http\Requests\Tasks\StoreTaskRequest;
use App\Http\Requests\Tasks\UpdateTaskRequest;
use App\Http\Resources\TaskResource;
use App\Models\Task;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Carbon\Carbon;

class TaskController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return TaskResource::collection(
            $request->user()->tasks()->orderBy('due_date', 'asc')->get()
        );
    }

    public function show(Task $task): TaskResource
    {
        Gate::authorize('update', $task);

        return new TaskResource($task);
    }

    public function store(StoreTaskRequest $request): JsonResponse
    {
        $task = $request->user()->tasks()->create($request->validated());

        return (new TaskResource($task))->response()->setStatusCode(201);
    }

    public function update(UpdateTaskRequest $request, Task $task): TaskResource
    {
        Gate::authorize('update', $task);

        $validated = $request->validated();

        // A recurring task marked done rolls its due date forward and goes back to "todo".
        if (($validated['status'] ?? null) === 'done' && $task->recurrence_rule) {
            $currentDate = $task->due_date
                ? Carbon::parse($task->due_date)
                : $request->user()->localNow();

            $validated['due_date'] = match ($task->recurrence_rule) {
                'daily' => $currentDate->addDay(),
                'weekly' => $currentDate->addWeek(),
                'monthly' => $currentDate->addMonth(),
            };
            $validated['status'] = 'todo';
        }

        $task->update($validated);

        return new TaskResource($task);
    }

    public function destroy(Task $task): JsonResponse
    {
        Gate::authorize('delete', $task);

        $task->delete();

        return response()->json(null, 204);
    }
}
