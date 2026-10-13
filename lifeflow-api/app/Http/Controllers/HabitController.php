<?php

namespace App\Http\Controllers;

use App\Models\Habit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Carbon\Carbon;

class HabitController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $habits = Habit::where('user_id', $request->user()->id)->get();

        // Streaks go stale when a day is missed without any toggle, so refresh
        // them from the logs before returning.
        $habits->each(fn (Habit $habit) => $this->recalculateStreaks($habit));

        $sevenDaysAgo = Carbon::now()->subDays(6)->toDateString();
        $habits->load(['logs' => function ($query) use ($sevenDaysAgo) {
            $query->where('completed_date', '>=', $sevenDaysAgo)
                  ->orderBy('completed_date', 'asc');
        }]);

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

    public function update(Request $request, Habit $habit): JsonResponse
    {
        Gate::authorize('update', $habit);

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'color_hex' => 'nullable|string|max:7',
        ]);

        $habit->update($validated);
        return response()->json($habit->load('logs'));
    }

    public function toggle(Request $request, Habit $habit): JsonResponse
    {
        Gate::authorize('update', $habit);

        $today = Carbon::now()->toDateString();
        $existingLog = $habit->logs()->whereDate('completed_date', $today)->first();

        if ($existingLog) {
            $existingLog->delete();
        } else {
            $habit->logs()->create(['completed_date' => $today]);
        }

        $this->recalculateStreaks($habit);

        return response()->json($habit->load('logs'));
    }

    public function destroy(Request $request, Habit $habit): JsonResponse
    {
        Gate::authorize('delete', $habit);

        $habit->delete();
        return response()->json(null, 204);
    }

    /**
     * Derive streaks from the logs instead of incrementing counters, which
     * drifted whenever a day was missed or a check-in was undone.
     *
     * current_streak: consecutive days ending today, or ending yesterday if
     * today isn't checked yet (the streak is still alive until midnight).
     */
    private function recalculateStreaks(Habit $habit): void
    {
        $days = $habit->logs()
            ->orderBy('completed_date')
            ->pluck('completed_date')
            ->map(fn ($date) => Carbon::parse($date)->toDateString())
            ->unique()
            ->values();

        $longest = 0;
        $run = 0;
        $previous = null;
        foreach ($days as $day) {
            $continues = $previous !== null
                && Carbon::parse($previous)->addDay()->toDateString() === $day;
            $run = $continues ? $run + 1 : 1;
            $longest = max($longest, $run);
            $previous = $day;
        }

        $logged = $days->flip();
        $cursor = Carbon::today();
        if (! $logged->has($cursor->toDateString())) {
            $cursor->subDay();
        }
        $current = 0;
        while ($logged->has($cursor->toDateString())) {
            $current++;
            $cursor->subDay();
        }

        if ($habit->current_streak !== $current || $habit->longest_streak !== $longest) {
            $habit->current_streak = $current;
            $habit->longest_streak = $longest;
            $habit->save();
        }
    }
}
