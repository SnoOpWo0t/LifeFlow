<?php

namespace App\Http\Controllers;

use App\Http\Requests\Expenses\StoreCategoryRequest;
use App\Http\Requests\Expenses\StoreTransactionRequest;
use App\Http\Requests\Expenses\UpdateCategoryRequest;
use App\Http\Requests\Expenses\UpdateTransactionRequest;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\TransactionResource;
use App\Models\ExpenseCategory;
use App\Models\Transaction;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class ExpenseController extends Controller
{
    public function getCategories(Request $request): AnonymousResourceCollection
    {
        return CategoryResource::collection($request->user()->expenseCategories()->get());
    }

    public function storeCategory(StoreCategoryRequest $request): JsonResponse
    {
        $category = $request->user()->expenseCategories()->create($request->validated());

        return (new CategoryResource($category))->response()->setStatusCode(201);
    }

    public function updateCategory(UpdateCategoryRequest $request, ExpenseCategory $category): CategoryResource
    {
        Gate::authorize('update', $category);

        $category->update($request->validated());

        return new CategoryResource($category);
    }

    /**
     * Transactions keep their amounts; their category becomes empty. Done
     * row by row (not by the foreign key) so the change syncs to devices.
     */
    public function destroyCategory(ExpenseCategory $category): JsonResponse
    {
        Gate::authorize('delete', $category);

        Transaction::where('category_id', $category->id)->get()
            ->each(fn (Transaction $tx) => $tx->update(['category_id' => null]));
        $category->delete();

        return response()->json(null, 204);
    }

    /**
     * Newest first, 30 per page: {"data": [...], "links": {...}, "meta": {...}}.
     * Use ?page=2 and so on; meta.last_page says when to stop.
     */
    public function getTransactions(Request $request): AnonymousResourceCollection
    {
        $transactions = Transaction::with('category')
            ->where('user_id', $request->user()->id)
            ->orderBy('transaction_date', 'desc')
            ->orderBy('id', 'desc')
            ->paginate(30);

        return TransactionResource::collection($transactions);
    }

    public function storeTransaction(StoreTransactionRequest $request): JsonResponse
    {
        $transaction = Transaction::create(array_merge(
            $request->validated(),
            ['user_id' => $request->user()->id],
        ));

        return (new TransactionResource($transaction->load('category')))
            ->response()
            ->setStatusCode(201);
    }

    public function updateTransaction(UpdateTransactionRequest $request, Transaction $transaction): TransactionResource
    {
        Gate::authorize('update', $transaction);

        $transaction->update($request->validated());

        return new TransactionResource($transaction->load('category'));
    }

    public function destroyTransaction(Transaction $transaction): JsonResponse
    {
        Gate::authorize('delete', $transaction);

        $transaction->delete();

        return response()->json(null, 204);
    }

    /** Daily income/expense totals for the last 7 local days (bar chart). */
    public function getChartData(Request $request): JsonResponse
    {
        $startDateStr = $request->user()->localNow()->subDays(6)->format('Y-m-d');

        $transactions = Transaction::where('user_id', $request->user()->id)
            ->where('transaction_date', '>=', $startDateStr)
            ->get();

        $grouped = [];
        foreach ($transactions as $tx) {
            $date = Carbon::parse($tx->transaction_date)->format('Y-m-d');
            $key = $date . '_' . $tx->type;
            $grouped[$key] ??= ['transaction_date' => $date, 'type' => $tx->type, 'total' => 0];
            $grouped[$key]['total'] += $tx->amount;
        }

        return response()->json(array_values($grouped));
    }

    /**
     * This month's spending per category (donut chart). Computed here because
     * the transaction list is paginated, so the app no longer has every row.
     */
    public function spendingByCategory(Request $request): JsonResponse
    {
        $now = $request->user()->localNow();
        $from = $now->copy()->startOfMonth()->toDateString();
        $until = $now->copy()->addMonthNoOverflow()->startOfMonth()->toDateString();

        $rows = Transaction::with('category')
            ->where('user_id', $request->user()->id)
            ->where('type', 'expense')
            ->where('transaction_date', '>=', $from)
            ->where('transaction_date', '<', $until)
            ->get()
            ->groupBy('category_id')
            ->map(fn ($group) => [
                'category_id' => $group->first()->category_id,
                'name' => $group->first()->category?->name ?? 'Uncategorised',
                'color_hex' => $group->first()->category?->color_hex,
                'total' => round($group->sum('amount'), 2),
            ])
            ->sortByDesc('total')
            ->values();

        return response()->json([
            'month' => $now->format('Y-m'),
            'categories' => $rows,
        ]);
    }
}
