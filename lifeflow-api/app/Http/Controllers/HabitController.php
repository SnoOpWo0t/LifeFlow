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
        $habits->each(fn (Habit $habit) => $habit->refreshStreaks($today));

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
        // Unchecking leaves a tombstone (for sync), so checking again restores it.
        $log = $habit->logs()->withTrashed()->whereDate('completed_date', $today)->first();

        if (! $log) {
            $habit->logs()->create(['completed_date' => $today]);
        } elseif ($log->trashed()) {
            $log->restore();
        } else {
            $log->delete();
        }

        $habit->refreshStreaks($localToday);

        return new HabitResource($habit->load('logs'));
    }

    public function destroy(Habit $habit): JsonResponse
    {
        Gate::authorize('delete', $habit);

        $habit->delete();
        return response()->json(null, 204);
    }
}
