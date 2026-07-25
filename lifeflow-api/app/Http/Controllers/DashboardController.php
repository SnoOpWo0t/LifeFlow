<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\Task;
use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\Transaction;

class DashboardController extends Controller
{
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();
        $today = now()->startOfDay();
        $startOfMonth = now()->startOfMonth();
        
        // Tasks
        $tasksToday = Task::where('user_id', $user->id)->get();
            
        $tasksCompleted = $tasksToday->where('status', 'done')->count();
        $tasksTotal = $tasksToday->count();

        // Habits
        $habits = Habit::where('user_id', $user->id)->get();
        $habitsTotal = $habits->count();
        
        $habitsCompleted = HabitLog::whereIn('habit_id', $habits->pluck('id'))
            ->whereDate('completed_date', '=', now()->toDateString())
            ->count();

        // Monthly Expenses
        $monthlyExpenses = Transaction::where('user_id', $user->id)
            ->where('type', 'expense')
            ->whereDate('transaction_date', '>=', $startOfMonth)
            ->sum('amount');
            
        // Monthly Income (Budget)
        $monthlyIncome = Transaction::where('user_id', $user->id)
            ->where('type', 'income')
            ->whereDate('transaction_date', '>=', $startOfMonth)
            ->sum('amount');

        // Productivity Score
        $taskScore = $tasksTotal > 0 ? ($tasksCompleted / $tasksTotal) : 0;
        $habitScore = $habitsTotal > 0 ? ($habitsCompleted / $habitsTotal) : 0;
        
        $divisor = 0;
        if ($tasksTotal > 0) $divisor++;
        if ($habitsTotal > 0) $divisor++;
        
        $productivityScore = $divisor > 0 ? (($taskScore + $habitScore) / $divisor) * 100 : 0;

        return response()->json([
            'tasks_today' => [
                'completed' => $tasksCompleted,
                'total' => $tasksTotal
            ],
            'habits_today' => [
                'completed' => $habitsCompleted,
                'total' => $habitsTotal
            ],
            'monthly_expenses' => (float) $monthlyExpenses,
            'monthly_income' => (float) $monthlyIncome,
            'productivity_score' => (int) round($productivityScore)
        ]);
    }
}
