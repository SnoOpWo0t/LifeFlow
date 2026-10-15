<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\Task;
use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\Saving;
use App\Models\Transaction;

class DashboardController extends Controller
{
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();
        // The user's local day, converted to server time for timestamp columns.
        $localNow = $user->localNow();
        $startOfMonth = $localNow->copy()->startOfMonth()->toDateString();
        $dayStart = $localNow->copy()->startOfDay()->setTimezone(config('app.timezone'));
        $dayEnd = $localNow->copy()->endOfDay()->setTimezone(config('app.timezone'));
        
        // Today's tasks: due today, overdue and still open, or finished today.
        // (This used to count every task the user had ever created.)
        $todayDate = $localNow->toDateString();
        $tasksToday = Task::where('user_id', $user->id)
            ->where(function ($query) use ($todayDate, $dayStart, $dayEnd) {
                $query->whereDate('due_date', $todayDate)
                    ->orWhere(function ($overdue) use ($todayDate) {
                        $overdue->whereDate('due_date', '<', $todayDate)->where('status', '!=', 'done');
                    })
                    ->orWhere(function ($finished) use ($dayStart, $dayEnd) {
                        $finished->where('status', 'done')->whereBetween('updated_at', [$dayStart, $dayEnd]);
                    });
            })
            ->get();

        $tasksCompleted = $tasksToday->where('status', 'done')->count();
        $tasksTotal = $tasksToday->count();

        // Habits
        $habits = Habit::where('user_id', $user->id)->get();
        $habitsTotal = $habits->count();
        
        $habitsCompleted = HabitLog::whereIn('habit_id', $habits->pluck('id'))
            ->whereDate('completed_date', '=', $todayDate)
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

        // Per-account net balance (income − expense) for each wallet type.
        $accounts = ['cash', 'bkash', 'nagad', 'bank'];
        $accountBalances = [];
        foreach ($accounts as $acc) {
            $income = Transaction::where('user_id', $user->id)
                ->where('account', $acc)
                ->where('type', 'income')
                ->sum('amount');
            $expense = Transaction::where('user_id', $user->id)
                ->where('account', $acc)
                ->where('type', 'expense')
                ->sum('amount');
            $accountBalances[$acc] = (float) ($income - $expense);
        }

        // Savings summary per account (Cash, bKash, Nagad, Bank) and total
        $savingsBalances = [];
        $totalSavings = 0.0;
        foreach ($accounts as $acc) {
            $dep = (float) Saving::where('user_id', $user->id)
                ->where('account', $acc)
                ->where('type', 'deposit')
                ->sum('amount');
            $with = (float) Saving::where('user_id', $user->id)
                ->where('account', $acc)
                ->where('type', 'withdrawal')
                ->sum('amount');
            $net = $dep - $with;
            $savingsBalances[$acc] = round($net, 2);
            $totalSavings += $net;
        }

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
            'recent_activity' => $recentActivity,
            'account_balances' => $accountBalances,
            'savings_summary' => [
                'total' => round($totalSavings, 2),
                'by_account' => $savingsBalances,
            ],
        ]);
    }
}
