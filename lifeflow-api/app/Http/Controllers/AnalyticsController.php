<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Carbon\Carbon;
use App\Models\Task;
use App\Models\Transaction;
use App\Models\Habit;
use App\Models\HabitLog;

class AnalyticsController extends Controller
{
    public function weekly(Request $request)
    {
        $user = $request->user();
        
        $startDate = Carbon::now()->subDays(6)->startOfDay();
        $endDate = Carbon::now()->endOfDay();

        // Initialize 7 days array
        $days = [];
        for ($i = 0; $i < 7; $i++) {
            $dateStr = Carbon::now()->subDays(6 - $i)->format('Y-m-d');
            $days[$dateStr] = [
                'day_name' => Carbon::now()->subDays(6 - $i)->format('D'),
                'tasks_completed' => 0,
                'habits_completed' => 0,
                'expenses' => 0,
                'income' => 0,
                'productivity_score' => 0, // tasks + habits
            ];
        }

        // 1. Fetch Tasks Completed
        $tasks = Task::where('user_id', $user->id)
            ->where('status', 'done')
            ->where('updated_at', '>=', $startDate->startOfDay())
            ->where('updated_at', '<=', $endDate->endOfDay())
            ->get();

        foreach ($tasks as $task) {
            $date = $task->updated_at->format('Y-m-d');
            if (isset($days[$date])) {
                $days[$date]['tasks_completed'] += 1;
                $days[$date]['productivity_score'] += 1;
            }
        }

        // 2. Fetch Habits Completed
        $habitIds = Habit::where('user_id', $user->id)->pluck('id');
        $habitLogs = HabitLog::whereIn('habit_id', $habitIds)
            ->whereBetween('completed_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->get();

        foreach ($habitLogs as $log) {
            $date = Carbon::parse($log->completed_date)->format('Y-m-d');
            if (isset($days[$date])) {
                $days[$date]['habits_completed'] += 1;
                $days[$date]['productivity_score'] += 1;
            }
        }

        // 3. Fetch Transactions
        $startStr = $startDate->format('Y-m-d');
        $nextDayStr = $endDate->copy()->addDay()->format('Y-m-d');

        $transactions = Transaction::where('user_id', $user->id)
            ->where('transaction_date', '>=', $startStr)
            ->where('transaction_date', '<', $nextDayStr)
            ->get();

        $totalSavings = 0;
        foreach ($transactions as $tx) {
            $date = Carbon::parse($tx->transaction_date)->format('Y-m-d');
            if (isset($days[$date])) {
                if ($tx->type === 'expense') {
                    $days[$date]['expenses'] += $tx->amount;
                    $totalSavings -= $tx->amount;
                } else {
                    $days[$date]['income'] += $tx->amount;
                    $totalSavings += $tx->amount;
                }
            }
        }

        // 4. Find Most Productive Day
        $mostProductiveDay = null;
        $maxScore = -1;
        foreach ($days as $date => $data) {
            if ($data['productivity_score'] > $maxScore) {
                $maxScore = $data['productivity_score'];
                $mostProductiveDay = $data['day_name'];
            }
        }
        
        // If no productivity at all
        if ($maxScore == 0) {
            $mostProductiveDay = "None";
        }

        return response()->json([
            'weekly_data' => array_values($days),
            'total_savings' => $totalSavings,
            'most_productive_day' => $mostProductiveDay,
            'max_productivity_score' => $maxScore,
        ]);
    }
}
