<?php

namespace App\Http\Controllers;

use App\Models\Task;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Carbon\Carbon;

class TaskController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tasks = $request->user()->tasks()->orderBy('due_date', 'asc')->get();
        return response()->json($tasks);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'status' => 'required|in:todo,in_progress,done',
            'priority' => 'required|in:low,medium,high',
            'due_date' => 'nullable|date',
            'recurrence_rule' => 'nullable|in:daily,weekly,monthly',
        ]);

        $task = $request->user()->tasks()->create($validated);
        return response()->json($task, 201);
    }

    public function update(Request $request, Task $task): JsonResponse
    {
        if ($task->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $validated = $request->validate([
            'title' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'status' => 'sometimes|in:todo,in_progress,done',
            'priority' => 'sometimes|in:low,medium,high',
            'due_date' => 'nullable|date',
            'recurrence_rule' => 'nullable|in:daily,weekly,monthly',
        ]);

        // Handle recurring task logic: If marked as done and it's recurring, roll date forward
        if (isset($validated['status']) && $validated['status'] === 'done' && $task->recurrence_rule) {
            $currentDate = $task->due_date ? Carbon::parse($task->due_date) : Carbon::now();
            
            switch ($task->recurrence_rule) {
                case 'daily':
                    $validated['due_date'] = $currentDate->addDay();
                    break;
                case 'weekly':
                    $validated['due_date'] = $currentDate->addWeek();
                    break;
                case 'monthly':
                    $validated['due_date'] = $currentDate->addMonth();
                    break;
            }
            // Reset status back to todo for the next recurrence
            $validated['status'] = 'todo';
        }

        $task->update($validated);
        return response()->json($task);
    }

    public function destroy(Request $request, Task $task): JsonResponse
    {
        if ($task->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden'], 403);
        }
        
        $task->delete();
        return response()->json(null, 204);
    }
}
