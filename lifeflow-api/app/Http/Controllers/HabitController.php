<?php

namespace App\Http\Controllers;

use App\Http\Requests\Habits\StoreHabitRequest;
use App\Http\Requests\Habits\UpdateHabitRequest;
use App\Http\Resources\HabitResource;
use App\Models\Habit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Carbon\Carbon;

class HabitController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $today = $request->user()->localNow()->startOfDay();
        $habits = Habit::where('user_id', $request->user()->id)->get();

        // Streaks go stale when a day is missed without any toggle, so refresh
        // them from the logs before returning.
        $habits->each(fn (Habit $habit) => $this->recalculateStreaks($habit, $today));

        $sevenDaysAgo = $today->copy()->subDays(6)->toDateString();
        $habits->load(['logs' => function ($query) use ($sevenDaysAgo) {
            $query->where('completed_date', '>=', $sevenDaysAgo)
                  ->orderBy('completed_date', 'asc');
        }]);

        return HabitResource::collection($habits);
    }

    public function store(StoreHabitRequest $request): JsonResponse
    {
        $habit = $request->user()->habits()->create($request->validated());

        return (new HabitResource($habit->load('logs')))->response()->setStatusCode(201);
    }

    public function update(UpdateHabitRequest $request, Habit $habit): HabitResource
    {
        Gate::authorize('update', $habit);

        $habit->update($request->validated());

        return new HabitResource($habit->load('logs'));
    }

    public function toggle(Request $request, Habit $habit): HabitResource
    {
        Gate::authorize('update', $habit);

        $localToday = $request->user()->localNow()->startOfDay();
        $today = $localToday->toDateString();
        $existingLog = $habit->logs()->whereDate('completed_date', $today)->first();

        if ($existingLog) {
            $existingLog->delete();
        } else {
            $habit->logs()->create(['completed_date' => $today]);
        }

        $this->recalculateStreaks($habit, $localToday);

        return new HabitResource($habit->load('logs'));
    }

    public function destroy(Habit $habit): JsonResponse
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
    private function recalculateStreaks(Habit $habit, Carbon $today): void
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
        $cursor = $today->copy();
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
