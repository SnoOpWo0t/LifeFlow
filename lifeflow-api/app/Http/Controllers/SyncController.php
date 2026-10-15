<?php

namespace App\Http\Controllers;

use App\Models\Bill;
use App\Models\ExpenseCategory;
use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\Saving;
use App\Models\SavingsGoal;
use App\Models\Task;
use App\Models\Transaction;
use App\Models\User;
use App\Models\WishlistItem;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Offline-first sync for the app. The phone keeps everything in its own
 * database and calls this with what changed since its last sync:
 *
 *   POST /sync {"since": "<cursor or null>", "changes": {"tasks": [...], ...}}
 *
 * Each record is {"id": "<uuid>", ...fields, "updated_at", "deleted_at"}.
 * The newest edit wins (by the device's edit time). The reply holds every
 * record changed since `since` (deletes included) and the next cursor:
 *
 *   {"cursor": "...", "changes": {...}, "rejected": {"tasks": ["<uuid>"]}}
 *
 * Foreign keys travel as uuids: transactions.category_id, habit_logs.habit_id.
 */
class SyncController extends Controller
{
    /** Parents before children, so references resolve in one request. */
    private const COLLECTIONS = ['categories', 'tasks', 'habits', 'habit_logs', 'transactions', 'wishlist', 'savings', 'bills', 'savings_goals'];

    private const MAX_PER_COLLECTION = 1000;

    public function __invoke(Request $request): JsonResponse
    {
        $request->validate([
            'since' => ['nullable', 'date'],
            'changes' => ['sometimes', 'array'],
            'changes.*' => ['array', 'max:'.self::MAX_PER_COLLECTION],
        ]);

        $user = $request->user();
        $cursor = now()->format('Y-m-d H:i:s');
        $since = $request->filled('since') ? $this->time($request->input('since')) : null;

        $rejected = [];
        $stale = []; // incoming edits older than ours: send ours back
        $touchedHabits = [];

        DB::transaction(function () use ($request, $user, &$rejected, &$stale, &$touchedHabits) {
            foreach (self::COLLECTIONS as $collection) {
                foreach ($request->input("changes.$collection", []) as $record) {
                    $result = is_array($record)
                        ? $this->apply($user, $collection, $record, $touchedHabits)
                        : 'rejected';
                    $id = is_array($record) ? (string) ($record['id'] ?? '') : '';
                    if ($result === 'rejected') {
                        $rejected[$collection][] = $id;
                    } elseif ($result === 'stale') {
                        $stale[$collection][] = $id;
                    }
                }
            }
        });

        if ($touchedHabits) {
            $today = $user->localNow()->startOfDay();
            Habit::whereIn('id', array_keys($touchedHabits))->get()->each->refreshStreaks($today);
        }

        $changes = [];
        foreach (self::COLLECTIONS as $collection) {
            $changes[$collection] = $this->changedSince($user, $collection, $since, $stale[$collection] ?? []);
        }

        return response()->json([
            'cursor' => $cursor,
            'changes' => $changes,
            'rejected' => (object) $rejected,
        ]);
    }

    // ------------------------------------------------------------------ push

    /** @return 'applied'|'stale'|'skipped'|'rejected' */
    private function apply(User $user, string $collection, array $record, array &$touchedHabits): string
    {
        $validator = Validator::make($record, $this->rules($collection) + [
            'id' => ['required', 'string', 'max:64'],
            'updated_at' => ['required', 'date'],
            'deleted_at' => ['nullable', 'date'],
            'created_at' => ['nullable', 'date'],
        ]);
        if ($validator->fails()) {
            return 'rejected';
        }

        $editedAt = $this->time($record['updated_at']);
        $deletedAt = isset($record['deleted_at']) ? $this->time($record['deleted_at']) : null;

        if ($collection === 'habit_logs') {
            return $this->applyHabitLog($user, $record, $editedAt, $deletedAt, $touchedHabits);
        }

        $class = $this->model($collection);
        $model = $class::withTrashed()->where('uuid', $record['id'])->first();
        if ($model && (int) $model->user_id !== (int) $user->id) {
            return 'rejected'; // someone else's id
        }
        if (! $model && $deletedAt) {
            return 'skipped'; // created and deleted offline: nothing to keep
        }
        if ($model && $model->client_updated_at && $model->client_updated_at->gt($editedAt)) {
            return 'stale';
        }

        $model ??= new $class(['user_id' => $user->id]);
        $model->user_id = $user->id;
        $model->uuid = $record['id'];
        $model->forceFill($this->fields($user, $collection, $record));
        $model->client_updated_at = $editedAt;
        $model->deleted_at = $deletedAt;
        if (! $model->exists && isset($record['created_at'])) {
            $model->created_at = $this->time($record['created_at']);
        }
        $model->save();

        return 'applied';
    }

    /** Logs are one row per habit and day, whatever device made them. */
    private function applyHabitLog(User $user, array $record, Carbon $editedAt, ?Carbon $deletedAt, array &$touchedHabits): string
    {
        $habit = Habit::withTrashed()->where('user_id', $user->id)->where('uuid', $record['habit_id'])->first();
        if (! $habit) {
            return 'rejected';
        }

        $date = $record['completed_date'];
        $log = HabitLog::withTrashed()->where('habit_id', $habit->id)->whereDate('completed_date', $date)->first();
        if (! $log && $deletedAt) {
            return 'skipped';
        }
        if ($log && $log->client_updated_at && $log->client_updated_at->gt($editedAt)) {
            return 'stale';
        }

        $log ??= new HabitLog(['habit_id' => $habit->id, 'completed_date' => $date]);
        $log->uuid = $habit->uuid.'_'.$date;
        $log->client_updated_at = $editedAt;
        $log->deleted_at = $deletedAt;
        $log->save();
        $touchedHabits[$habit->id] = true;

        return 'applied';
    }

    private function rules(string $collection): array
    {
        return match ($collection) {
            'categories' => [
                'name' => ['required', 'string', 'max:255'],
                'type' => ['required', 'in:income,expense'],
                'color_hex' => ['nullable', 'string', 'max:7'],
            ],
            'tasks' => [
                'title' => ['required', 'string', 'max:255'],
                'description' => ['nullable', 'string'],
                'status' => ['required', 'in:todo,in_progress,done'],
                'priority' => ['required', 'in:low,medium,high'],
                'due_date' => ['nullable', 'date'],
                'recurrence_rule' => ['nullable', 'in:daily,weekly,monthly'],
            ],
            'habits' => [
                'name' => ['required', 'string', 'max:255'],
                'color_hex' => ['nullable', 'string', 'max:7'],
            ],
            'habit_logs' => [
                'habit_id' => ['required', 'string', 'max:64'],
                'completed_date' => ['required', 'date_format:Y-m-d'],
            ],
            'transactions' => [
                'category_id' => ['nullable', 'string', 'max:64'],
                'amount' => ['required', 'numeric', 'min:0.01'],
                'type' => ['required', 'in:income,expense'],
                'account' => ['nullable', 'in:cash,bkash,nagad,bank'],
                'transaction_date' => ['required', 'date'],
                'note' => ['nullable', 'string'],
            ],
            'wishlist' => [
                'title' => ['required', 'string', 'max:255'],
                'note' => ['nullable', 'string'],
                'estimated_price' => ['nullable', 'numeric', 'min:0'],
                'priority' => ['nullable', 'in:low,normal,high'],
                'category' => ['nullable', 'string', 'max:60'],
                'is_purchased' => ['nullable', 'boolean'],
                'link' => ['nullable', 'string', 'max:2048'],
                'sort_order' => ['nullable', 'integer'],
            ],
            'savings' => [
                'amount' => ['required', 'numeric', 'min:0.01'],
                'type' => ['required', 'in:deposit,withdrawal'],
                'account' => ['required', 'in:cash,bkash,nagad,bank'],
                'transaction_date' => ['required', 'date'],
                'note' => ['nullable', 'string', 'max:500'],
            ],
            'bills' => [
                'title' => ['required', 'string', 'max:255'],
                'category_id' => ['nullable', 'string', 'max:64'],
                'amount' => ['required', 'numeric', 'min:0.01'],
                'due_date' => ['required', 'date'],
                'frequency' => ['required', 'in:one_time,weekly,monthly,quarterly,yearly'],
                'account' => ['nullable', 'in:cash,bkash,nagad,bank'],
                'is_paid' => ['nullable', 'boolean'],
                'last_paid_at' => ['nullable', 'date'],
                'note' => ['nullable', 'string', 'max:500'],
            ],
            'savings_goals' => [
                'title' => ['required', 'string', 'max:255'],
                'target_amount' => ['required', 'numeric', 'min:0.01'],
                'saved_amount' => ['nullable', 'numeric', 'min:0'],
                'target_date' => ['nullable', 'date'],
                'category' => ['nullable', 'string', 'max:60'],
                'color_hex' => ['nullable', 'string', 'max:7'],
                'is_completed' => ['nullable', 'boolean'],
            ],
        };
    }

    private function fields(User $user, string $collection, array $r): array
    {
        return match ($collection) {
            'categories' => ['name' => $r['name'], 'type' => $r['type'], 'color_hex' => $r['color_hex'] ?? null],
            'tasks' => [
                'title' => $r['title'],
                'description' => $r['description'] ?? null,
                'status' => $r['status'],
                'priority' => $r['priority'],
                'due_date' => isset($r['due_date']) ? Carbon::parse($r['due_date'])->format('Y-m-d H:i:s') : null,
                'recurrence_rule' => $r['recurrence_rule'] ?? null,
            ],
            'habits' => ['name' => $r['name'], 'color_hex' => $r['color_hex'] ?? null],
            'transactions' => [
                // A category this user doesn't have (or not yet) leaves it empty.
                'category_id' => isset($r['category_id'])
                    ? ExpenseCategory::withTrashed()->where('user_id', $user->id)->where('uuid', $r['category_id'])->value('id')
                    : null,
                'amount' => $r['amount'],
                'type' => $r['type'],
                'account' => $r['account'] ?? 'cash',
                'transaction_date' => substr((string) $r['transaction_date'], 0, 10),
                'note' => $r['note'] ?? null,
            ],
            'wishlist' => [
                'title' => $r['title'],
                'note' => $r['note'] ?? null,
                'estimated_price' => $r['estimated_price'] ?? null,
                'priority' => $r['priority'] ?? 'normal',
                'category' => $r['category'] ?? null,
                'is_purchased' => (bool) ($r['is_purchased'] ?? false),
                'link' => $r['link'] ?? null,
                'sort_order' => (int) ($r['sort_order'] ?? 0),
            ],
            'savings' => [
                'amount' => $r['amount'],
                'type' => $r['type'],
                'account' => $r['account'] ?? 'cash',
                'transaction_date' => substr((string) $r['transaction_date'], 0, 10),
                'note' => $r['note'] ?? null,
            ],
            'bills' => [
                'title' => $r['title'],
                'category_id' => isset($r['category_id'])
                    ? ExpenseCategory::withTrashed()->where('user_id', $user->id)->where('uuid', $r['category_id'])->value('id')
                    : null,
                'amount' => $r['amount'],
                'due_date' => substr((string) $r['due_date'], 0, 10),
                'frequency' => $r['frequency'] ?? 'monthly',
                'account' => $r['account'] ?? 'bank',
                'is_paid' => (bool) ($r['is_paid'] ?? false),
                'last_paid_at' => isset($r['last_paid_at']) ? substr((string) $r['last_paid_at'], 0, 10) : null,
                'note' => $r['note'] ?? null,
            ],
            'savings_goals' => [
                'title' => $r['title'],
                'target_amount' => $r['target_amount'],
                'saved_amount' => $r['saved_amount'] ?? 0.00,
                'target_date' => isset($r['target_date']) ? substr((string) $r['target_date'], 0, 10) : null,
                'category' => $r['category'] ?? null,
                'color_hex' => $r['color_hex'] ?? null,
                'is_completed' => (bool) ($r['is_completed'] ?? false),
            ],
        };
    }

    // ------------------------------------------------------------------ pull

    private function changedSince(User $user, string $collection, ?Carbon $since, array $alsoIds): array
    {
        $query = $collection === 'habit_logs'
            ? HabitLog::withTrashed()->whereIn('habit_id', Habit::withTrashed()->where('user_id', $user->id)->select('id'))
            : $this->model($collection)::withTrashed()->where('user_id', $user->id);

        $query->where(function ($q) use ($since, $alsoIds) {
            if ($since) {
                $q->where('updated_at', '>=', $since->format('Y-m-d H:i:s'));
            } else {
                $q->whereNull('deleted_at'); // first sync: no tombstones needed
            }
            if ($alsoIds) {
                $q->orWhereIn('uuid', $alsoIds);
            }
        });

        $rows = $query->orderBy('id')->get();

        $uuids = match ($collection) {
            'transactions', 'bills' => ExpenseCategory::withTrashed()->where('user_id', $user->id)->pluck('uuid', 'id'),
            'habit_logs' => Habit::withTrashed()->where('user_id', $user->id)->pluck('uuid', 'id'),
            default => collect(),
        };

        return $rows->map(fn (Model $row) => $this->present($collection, $row, $uuids))->all();
    }

    private function present(string $collection, Model $row, $uuids): array
    {
        $time = fn ($t) => $t ? Carbon::parse($t)->utc()->format('Y-m-d\TH:i:s.v\Z') : null;
        $money = fn ($v) => $v === null ? null : round((float) $v, 2);

        return ['id' => $row->uuid] + match ($collection) {
            'categories' => ['name' => $row->name, 'type' => $row->type, 'color_hex' => $row->color_hex],
            'tasks' => [
                'title' => $row->title,
                'description' => $row->description,
                'status' => $row->status,
                'priority' => $row->priority,
                // Wall-clock time as the app sent it (no timezone).
                'due_date' => $row->due_date?->format('Y-m-d\TH:i:s'),
                'recurrence_rule' => $row->recurrence_rule,
            ],
            'habits' => ['name' => $row->name, 'color_hex' => $row->color_hex],
            'habit_logs' => [
                'habit_id' => $uuids[$row->habit_id] ?? null,
                'completed_date' => substr((string) $row->completed_date, 0, 10),
            ],
            'transactions' => [
                'category_id' => $row->category_id ? ($uuids[$row->category_id] ?? null) : null,
                'amount' => $money($row->amount),
                'type' => $row->type,
                'account' => $row->account ?? 'cash',
                'transaction_date' => substr((string) $row->transaction_date, 0, 10),
                'note' => $row->note,
            ],
            'wishlist' => [
                'title' => $row->title,
                'note' => $row->note,
                'estimated_price' => $money($row->estimated_price),
                'priority' => $row->priority ?? 'normal',
                'category' => $row->category,
                'is_purchased' => (bool) $row->is_purchased,
                'link' => $row->link,
                'sort_order' => (int) $row->sort_order,
            ],
            'savings' => [
                'amount' => $money($row->amount),
                'type' => $row->type,
                'account' => $row->account ?? 'cash',
                'transaction_date' => substr((string) $row->transaction_date, 0, 10),
                'note' => $row->note,
            ],
            'bills' => [
                'title' => $row->title,
                'category_id' => $row->category_id ? ($uuids[$row->category_id] ?? null) : null,
                'amount' => $money($row->amount),
                'due_date' => substr((string) $row->due_date, 0, 10),
                'frequency' => $row->frequency ?? 'monthly',
                'account' => $row->account ?? 'bank',
                'is_paid' => (bool) $row->is_paid,
                'last_paid_at' => $row->last_paid_at ? substr((string) $row->last_paid_at, 0, 10) : null,
                'note' => $row->note,
            ],
            'savings_goals' => [
                'title' => $row->title,
                'target_amount' => $money($row->target_amount),
                'saved_amount' => $money($row->saved_amount),
                'target_date' => $row->target_date ? substr((string) $row->target_date, 0, 10) : null,
                'category' => $row->category,
                'color_hex' => $row->color_hex,
                'is_completed' => (bool) $row->is_completed,
            ],
        } + [
            'created_at' => $time($row->created_at),
            'updated_at' => $time($row->client_updated_at ?? $row->updated_at),
            'deleted_at' => $time($row->deleted_at),
        ];
    }

    /** Device times arrive in UTC; columns hold the app's timezone. */
    private function time(string $value): Carbon
    {
        return Carbon::parse($value)->setTimezone(config('app.timezone'));
    }

    /** @return class-string<Model> */
    private function model(string $collection): string
    {
        return match ($collection) {
            'categories' => ExpenseCategory::class,
            'tasks' => Task::class,
            'habits' => Habit::class,
            'transactions' => Transaction::class,
            'wishlist' => WishlistItem::class,
            'savings' => Saving::class,
            'bills' => Bill::class,
            'savings_goals' => SavingsGoal::class,
        };
    }
}
