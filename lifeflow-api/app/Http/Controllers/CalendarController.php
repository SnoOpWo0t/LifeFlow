<?php

namespace App\Http\Controllers;

use App\Http\Requests\Calendar\CalendarDayRequest;
use App\Http\Requests\Calendar\CalendarMonthRequest;
use App\Http\Resources\TaskResource;
use App\Http\Resources\TransactionResource;
use App\Models\HabitLog;
use App\Models\Transaction;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;

/**
 * The dashboard calendar: one month at a glance, plus the details of a day.
 * Dates are the user's local dates (see User::localNow()).
 */
class CalendarController extends Controller
{
    /**
     * Per-day activity for a month. Only days with something on them are
     * listed: tasks due (and how many are done), habits checked, and money
     * in and out.
     */
    public function month(CalendarMonthRequest $request): JsonResponse
    {
        $user = $request->user();
        $start = $request->filled('month')
            ? Carbon::createFromFormat('!Y-m', $request->validated('month'))
            : $user->localNow()->startOfMonth()->startOfDay();
        $from = $start->toDateString();
        $until = $start->copy()->addMonthNoOverflow()->toDateString();

        $days = [];
        $day = function (string $date) use (&$days) {
            return $days[$date] ??= [
                'date' => $date,
                'tasks_due' => 0,
                'tasks_done' => 0,
                'habits_done' => 0,
                'spent' => 0.0,
                'earned' => 0.0,
            ];
        };

        // Dates are stored as "YYYY-MM-DD…" strings, so a string range works
        // on SQLite and PostgreSQL alike.
        $tasks = $user->tasks()
            ->where('due_date', '>=', $from)
            ->where('due_date', '<', $until)
            ->get(['due_date', 'status']);
        foreach ($tasks as $task) {
            $date = Carbon::parse($task->due_date)->toDateString();
            $day($date);
            $days[$date]['tasks_due']++;
            if ($task->status === 'done') {
                $days[$date]['tasks_done']++;
            }
        }

        $habitIds = $user->habits()->pluck('id');
        $logs = HabitLog::whereIn('habit_id', $habitIds)
            ->where('completed_date', '>=', $from)
            ->where('completed_date', '<', $until)
            ->pluck('completed_date');
        foreach ($logs as $completed) {
            $date = Carbon::parse($completed)->toDateString();
            $day($date);
            $days[$date]['habits_done']++;
        }

        $transactions = Transaction::where('user_id', $user->id)
            ->where('transaction_date', '>=', $from)
            ->where('transaction_date', '<', $until)
            ->get(['transaction_date', 'type', 'amount']);
        foreach ($transactions as $tx) {
            $date = Carbon::parse($tx->transaction_date)->toDateString();
            $day($date);
            $days[$date][$tx->type === 'income' ? 'earned' : 'spent'] += (float) $tx->amount;
        }

        ksort($days);

        return response()->json([
            'month' => $start->format('Y-m'),
            'habits_total' => $habitIds->count(),
            'days' => array_values($days),
        ]);
    }

    /** Everything on one day: tasks due, each habit's check-in, transactions. */
    public function day(CalendarDayRequest $request): JsonResponse
    {
        $user = $request->user();
        $date = $request->validated('date');
        $next = Carbon::parse($date)->addDay()->toDateString();

        $tasks = $user->tasks()
            ->where('due_date', '>=', $date)
            ->where('due_date', '<', $next)
            ->orderBy('status')
            ->get();

        $habits = $user->habits()
            ->with(['logs' => fn ($q) => $q->where('completed_date', '>=', $date)->where('completed_date', '<', $next)])
            ->get()
            ->map(fn ($habit) => [
                'id' => $habit->id,
                'name' => $habit->name,
                'color_hex' => $habit->color_hex,
                'done' => $habit->logs->isNotEmpty(),
            ]);

        $transactions = Transaction::with('category')
            ->where('user_id', $user->id)
            ->where('transaction_date', '>=', $date)
            ->where('transaction_date', '<', $next)
            ->orderBy('id')
            ->get();

        return response()->json([
            'date' => $date,
            'tasks' => TaskResource::collection($tasks),
            'habits' => $habits,
            'transactions' => TransactionResource::collection($transactions),
        ]);
    }
}
