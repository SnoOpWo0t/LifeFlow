<?php

namespace App\Services;

use App\Models\HabitLog;
use App\Models\Saving;
use App\Models\Transaction;
use App\Models\User;
use Carbon\Carbon;
use Carbon\CarbonInterface;

/**
 * AI summaries: boils one week or month of the user's own data down to a
 * compact digest of numbers, and asks Gemini for a short summary with
 * suggestions. The client never sends free text, so the key can't be used
 * for anything else. Idea adapted from the Catalyst app's AI insights.
 */
class InsightWriter
{
    public function __construct(private Gemini $gemini)
    {
    }

    /** @return array{0: Carbon, 1: Carbon} first and last day of the period containing $day */
    public static function window(string $period, CarbonInterface $day): array
    {
        $day = Carbon::parse($day->toDateString());

        return $period === 'week'
            ? [$day->copy()->startOfWeek(Carbon::MONDAY), $day->copy()->endOfWeek(Carbon::SUNDAY)->startOfDay()]
            : [$day->copy()->startOfMonth(), $day->copy()->endOfMonth()->startOfDay()];
    }

    /**
     * Latest change to anything a summary of this window is built from, so the
     * app can say "there's newer data" without calling the AI.
     */
    public function lastChange(User $user, Carbon $from, Carbon $to): ?Carbon
    {
        $range = [$from->toDateString(), $to->copy()->addDay()->toDateString()];
        $stamps = array_filter([
            Transaction::where('user_id', $user->id)->where('transaction_date', '>=', $range[0])
                ->where('transaction_date', '<', $range[1])->max('updated_at'),
            $user->tasks()->max('updated_at'),
            HabitLog::whereIn('habit_id', $user->habits()->select('id'))
                ->where('completed_date', '>=', $range[0])->where('completed_date', '<', $range[1])->max('updated_at'),
            $user->wishlistItems()->max('updated_at'),
            $user->savings()->max('updated_at'),
        ]);

        return $stamps ? Carbon::parse(max($stamps)) : null;
    }

    /** @return array{ok: true, content: array}|array{ok: false, status: int, error: string} */
    public function write(User $user, string $period, Carbon $from, Carbon $to): array
    {
        $digest = $this->digest($user, $period, $from, $to);

        $result = $this->gemini->json(
            system: $this->prompt($period),
            parts: [['text' => json_encode($digest, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)]],
            schema: $this->schema(),
            tag: 'insights',
        );

        if (! $result['ok']) {
            return match ($result['reason']) {
                Gemini::BUSY => ['ok' => false, 'status' => 503, 'error' => 'The AI is busy right now. Try again in a minute.'],
                Gemini::FAILED => ['ok' => false, 'status' => 502, 'error' => "The AI couldn't write this summary. Try again."],
                default => ['ok' => false, 'status' => 502, 'error' => "The AI isn't available. Try again later."],
            };
        }

        return ['ok' => true, 'content' => $this->clean($result['json'])];
    }

    // ----------------------------------------------------------------- digest

    /** The numbers the summary is written from. Only this user's rows. */
    public function digest(User $user, string $period, Carbon $from, Carbon $to): array
    {
        $today = $user->localNow()->startOfDay();
        $end = $to->lessThan($today) ? $to : $today; // don't count days that haven't happened
        $days = $from->diffInDays($end) + 1;
        $length = $from->diffInDays($to) + 1;
        [$prevFrom, $prevTo] = [$from->copy()->subDays($length), $from->copy()->subDay()];

        return [
            'period' => $period,
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'today' => $today->toDateString(),
            'days_elapsed' => max(0, (int) $days),
            'currency' => 'BDT (৳)',
            'money' => $this->money($user, $from, $to, $prevFrom, $prevTo),
            'tasks' => $this->tasks($user, $from, $to, $today),
            'habits' => $this->habits($user, $from, $end),
            'wishlist' => [
                'wanted_items' => $user->wishlistItems()->where('is_purchased', false)->count(),
                'wanted_value' => round((float) $user->wishlistItems()->where('is_purchased', false)->sum('estimated_price'), 2),
                'high_priority_wanted' => $user->wishlistItems()->where('is_purchased', false)->where('priority', 'high')->count(),
                'bought_items' => $user->wishlistItems()->where('is_purchased', true)->count(),
            ],
            'savings' => [
                'total_saved' => round((float) ($user->savings()->where('type', 'deposit')->sum('amount') - $user->savings()->where('type', 'withdrawal')->sum('amount')), 2),
                'period_deposits' => round((float) $user->savings()->where('type', 'deposit')->where('transaction_date', '>=', $from->toDateString())->where('transaction_date', '<=', $to->toDateString())->sum('amount'), 2),
                'period_withdrawals' => round((float) $user->savings()->where('type', 'withdrawal')->where('transaction_date', '>=', $from->toDateString())->where('transaction_date', '<=', $to->toDateString())->sum('amount'), 2),
            ],
        ];
    }

    private function money(User $user, Carbon $from, Carbon $to, Carbon $prevFrom, Carbon $prevTo): array
    {
        $inRange = fn (Carbon $a, Carbon $b) => Transaction::with('category')
            ->where('user_id', $user->id)
            ->where('transaction_date', '>=', $a->toDateString())
            ->where('transaction_date', '<', $b->copy()->addDay()->toDateString())
            ->get();

        $rows = $inRange($from, $to);
        $previous = $inRange($prevFrom, $prevTo);
        $expenses = $rows->where('type', 'expense');
        $income = $rows->where('type', 'income');

        return [
            'income_total' => round((float) $income->sum('amount'), 2),
            'expense_total' => round((float) $expenses->sum('amount'), 2),
            'net' => round((float) $income->sum('amount') - (float) $expenses->sum('amount'), 2),
            'transactions' => $rows->count(),
            'previous_period' => [
                'income_total' => round((float) $previous->where('type', 'income')->sum('amount'), 2),
                'expense_total' => round((float) $previous->where('type', 'expense')->sum('amount'), 2),
            ],
            'spending_by_category' => $expenses
                ->groupBy(fn ($tx) => $tx->category?->name ?? 'Uncategorised')
                ->map(fn ($group) => round((float) $group->sum('amount'), 2))
                ->sortDesc()->take(8)->all(),
            'largest_expenses' => $expenses->sortByDesc('amount')->take(5)->map(fn ($tx) => [
                'amount' => round((float) $tx->amount, 2),
                'what' => mb_substr((string) ($tx->note ?: ($tx->category?->name ?? 'Expense')), 0, 60),
                'date' => substr((string) $tx->transaction_date, 0, 10),
            ])->values()->all(),
            'by_wallet' => $rows->groupBy(fn ($tx) => $tx->account ?? 'cash')
                ->map(fn ($group) => round((float) $group->where('type', 'income')->sum('amount') - (float) $group->where('type', 'expense')->sum('amount'), 2))
                ->all(),
            'monthly_budget' => (float) ($user->preferences['monthly_budget'] ?? 0),
        ];
    }

    private function tasks(User $user, Carbon $from, Carbon $to, Carbon $today): array
    {
        $dueInPeriod = $user->tasks()
            ->where('due_date', '>=', $from->toDateString())
            ->where('due_date', '<', $to->copy()->addDay()->toDateString());

        return [
            'due_in_period' => (clone $dueInPeriod)->count(),
            'done_of_those' => (clone $dueInPeriod)->where('status', 'done')->count(),
            'open_now' => $user->tasks()->where('status', '!=', 'done')->count(),
            'overdue_now' => $user->tasks()->where('status', '!=', 'done')
                ->where('due_date', '<', $today->toDateString())->count(),
            'open_high_priority' => $user->tasks()->where('status', '!=', 'done')->where('priority', 'high')->count(),
        ];
    }

    private function habits(User $user, Carbon $from, Carbon $end): array
    {
        $days = max(1, $from->diffInDays($end) + 1);

        return $user->habits()->withCount(['logs as checked' => fn ($q) => $q
            ->where('completed_date', '>=', $from->toDateString())
            ->where('completed_date', '<', $end->copy()->addDay()->toDateString())])
            ->get()
            ->map(fn ($habit) => [
                'name' => mb_substr($habit->name, 0, 60),
                'checked_days' => (int) $habit->checked,
                'of_days' => (int) $days,
                'current_streak' => $habit->current_streak,
                'longest_streak' => $habit->longest_streak,
            ])
            ->all();
    }

    // ---------------------------------------------------------- prompt/schema

    private function prompt(string $period): string
    {
        $span = $period === 'week' ? 'week' : 'month';

        return <<<PROMPT
        You are a friendly, practical assistant inside LifeFlow, a personal app for money, tasks and habits, used mostly in Bangladesh. You get a JSON digest of one {$span} of the user's own data (amounts in Bangladeshi taka, ৳). Write a short, honest summary and useful suggestions.

        Rules:
        - Use only the numbers in the digest; never invent figures. Write amounts like ৳1,250.
        - If the period isn't over yet (days_elapsed is less than the full period), say "so far".
        - Compare with previous_period when it helps (e.g. spending up or down).
        - headline: one sentence, at most 12 words.
        - summary: 2 to 4 sentences covering money first, then tasks and habits.
        - highlights: 2 to 4 short facts worth noticing (a top category, a big expense, a streak, overdue tasks).
        - suggestions: 2 to 4 concrete, kind next steps, each with a short title and a one- or two-sentence detail; area is money, tasks, habits or wishlist.
        - If there's almost no data, say so and suggest how to start tracking.
        - Plain English, warm but not cheesy, no emojis.
        PROMPT;
    }

    private function schema(): array
    {
        return [
            'type' => 'OBJECT',
            'properties' => [
                'headline' => ['type' => 'STRING'],
                'summary' => ['type' => 'STRING'],
                'highlights' => ['type' => 'ARRAY', 'items' => ['type' => 'STRING']],
                'suggestions' => [
                    'type' => 'ARRAY',
                    'items' => [
                        'type' => 'OBJECT',
                        'properties' => [
                            'title' => ['type' => 'STRING'],
                            'detail' => ['type' => 'STRING'],
                            'area' => ['type' => 'STRING', 'enum' => ['money', 'tasks', 'habits', 'wishlist']],
                        ],
                        'required' => ['title', 'detail', 'area'],
                    ],
                ],
            ],
            'required' => ['headline', 'summary', 'highlights', 'suggestions'],
        ];
    }

    /** Never trust model output: trim, cap lengths and counts. */
    private function clean(array $raw): array
    {
        $text = fn ($v, int $max) => is_string($v) ? mb_substr(trim(preg_replace('/\s+/u', ' ', $v)), 0, $max) : '';

        return [
            'headline' => $text($raw['headline'] ?? null, 160),
            'summary' => $text($raw['summary'] ?? null, 1200),
            'highlights' => collect(is_array($raw['highlights'] ?? null) ? $raw['highlights'] : [])
                ->map(fn ($h) => $text($h, 240))->filter()->take(5)->values()->all(),
            'suggestions' => collect(is_array($raw['suggestions'] ?? null) ? $raw['suggestions'] : [])
                ->filter(fn ($s) => is_array($s))
                ->map(fn ($s) => [
                    'title' => $text($s['title'] ?? null, 100),
                    'detail' => $text($s['detail'] ?? null, 400),
                    'area' => in_array($s['area'] ?? null, ['money', 'tasks', 'habits', 'wishlist'], true) ? $s['area'] : 'money',
                ])
                ->filter(fn ($s) => $s['title'] !== '')
                ->take(5)->values()->all(),
        ];
    }
}
