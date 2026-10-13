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
        
        // Today's tasks: due today, overdue and still open, or finished today.
        // (This used to count every task the user had ever created.)
        $todayDate = now()->toDateString();
        $tasksToday = Task::where('user_id', $user->id)
            ->where(function ($query) use ($todayDate) {
                $query->whereDate('due_date', $todayDate)
                    ->orWhere(function ($overdue) use ($todayDate) {
                        $overdue->whereDate('due_date', '<', $todayDate)->where('status', '!=', 'done');
                    })
                    ->orWhere(function ($finished) use ($todayDate) {
                        $finished->where('status', 'done')->whereDate('updated_at', $todayDate);
                    });
            })
            ->get();

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

        // Recent Activity
        $recentTransactions = Transaction::where('user_id', $user->id)
            ->with('category')
            ->orderBy('transaction_date', 'desc')
            ->orderBy('created_at', 'desc')
            ->limit(3)
            ->get()
            ->map(function($t) {
                return [
                    'id' => 'tx_'.$t->id,
                    'type' => 'transaction',
                    'title' => $t->note ?? $t->category?->name ?? 'Transaction',
                    'subtitle' => $t->type == 'income' ? 'Income' : 'Expense',
                    'amount' => $t->amount,
                    'is_income' => $t->type == 'income',
                    // The date the money moved, not when it was typed in. Same-day
                    // entries keep their entry time so they sort among today's tasks.
                    'date' => \Carbon\Carbon::parse($t->transaction_date)->isSameDay($t->created_at)
                        ? \Carbon\Carbon::parse($t->created_at)->toIso8601String()
                        : \Carbon\Carbon::parse($t->transaction_date)->endOfDay()->toIso8601String(),
                ];
            });

        $recentTasks = Task::where('user_id', $user->id)
            ->where('status', 'done')
            ->orderBy('updated_at', 'desc')
            ->limit(3)
            ->get()
            ->map(function($t) {
                return [
                    'id' => 'task_'.$t->id,
                    'type' => 'task',
                    'title' => $t->title,
                    'subtitle' => 'Completed Task',
                    'amount' => null,
                    'is_income' => null,
                    'date' => \Carbon\Carbon::parse($t->updated_at)->toIso8601String()
                ];
            });

        // toBase(): with no transactions this is an empty *Eloquent* collection,
        // whose merge() expects models and crashed on the task arrays.
        $recentActivity = $recentTransactions->toBase()->merge($recentTasks)
            ->sortByDesc('date')
            ->take(5)
            ->values();

        // Budget from preferences
        $monthlyBudget = isset($user->preferences['monthly_budget']) ? (float) $user->preferences['monthly_budget'] : 0;

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
            'monthly_budget' => $monthlyBudget,
            'productivity_score' => (int) round($productivityScore),
            'recent_activity' => $recentActivity
        ]);
    }
}
