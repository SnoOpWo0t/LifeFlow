<?php

namespace App\Http\Controllers;

use App\Models\Habit;
use App\Models\HabitLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Carbon\Carbon;

class HabitController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $sevenDaysAgo = Carbon::now()->subDays(6)->toDateString();
        
        $habits = Habit::with(['logs' => function ($query) use ($sevenDaysAgo) {
                $query->where('completed_date', '>=', $sevenDaysAgo)
                      ->orderBy('completed_date', 'asc');
            }])
            ->where('user_id', $request->user()->id)
            ->get();
            
        return response()->json($habits);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'color_hex' => 'nullable|string|max:7',
        ]);

        $habit = Habit::create(array_merge($validated, ['user_id' => $request->user()->id]));
        return response()->json($habit->load('logs'), 201);
    }

    public function toggle(Request $request, Habit $habit): JsonResponse
    {
        if ($habit->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $today = Carbon::now()->toDateString();
        
        $existingLog = $habit->logs()->where('completed_date', $today)->first();

        if ($existingLog) {
            $existingLog->delete();
            $habit->current_streak = max(0, $habit->current_streak - 1);
            $habit->save();
        } else {
            $habit->logs()->create(['completed_date' => $today]);
            
            // Basic streak calculation
            $yesterday = Carbon::now()->subDay()->toDateString();
            $completedYesterday = $habit->logs()->where('completed_date', $yesterday)->exists();
            
            if ($completedYesterday || $habit->current_streak == 0) {
                $habit->current_streak += 1;
            } else {
                $habit->current_streak = 1; // Resets missing streak
            }
            
            if ($habit->current_streak > $habit->longest_streak) {
                $habit->longest_streak = $habit->current_streak;
            }
            $habit->save();
        }

        return response()->json($habit->load('logs'));
    }

    public function destroy(Request $request, Habit $habit): JsonResponse
    {
        if ($habit->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden'], 403);
        }
        
        $habit->delete();
        return response()->json(null, 204);
    }
}
