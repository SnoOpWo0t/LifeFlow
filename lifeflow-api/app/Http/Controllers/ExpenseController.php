<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Models\ExpenseCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;
use Carbon\Carbon;

class ExpenseController extends Controller
{
    public function getCategories(Request $request): JsonResponse
    {
        return response()->json($request->user()->expenseCategories()->get());
    }

    public function storeCategory(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'type' => 'required|in:income,expense',
            'color_hex' => 'nullable|string|max:7',
        ]);
        
        $cat = ExpenseCategory::create(array_merge($validated, ['user_id' => $request->user()->id]));
        return response()->json($cat, 201);
    }

    public function updateCategory(Request $request, ExpenseCategory $category): JsonResponse
    {
        Gate::authorize('update', $category);

        $category->update($request->validate([
            'name' => 'sometimes|required|string|max:255',
            'type' => 'sometimes|required|in:income,expense',
            'color_hex' => 'nullable|string|max:7',
        ]));

        return response()->json($category);
    }

    /**
     * Transactions keep their amounts; their category becomes empty
     * (the foreign key is ON DELETE SET NULL).
     */
    public function destroyCategory(Request $request, ExpenseCategory $category): JsonResponse
    {
        Gate::authorize('delete', $category);

        $category->delete();
        return response()->json(null, 204);
    }

    public function getTransactions(Request $request): JsonResponse
    {
        $transactions = Transaction::with('category')
            ->where('user_id', $request->user()->id)
            ->orderBy('transaction_date', 'desc')
            ->get();
        return response()->json($transactions);
    }

    public function storeTransaction(Request $request): JsonResponse
    {
        $validated = $request->validate($this->transactionRules($request));

        $transaction = Transaction::create(array_merge($validated, ['user_id' => $request->user()->id]));
        return response()->json($transaction->load('category'), 201);
    }

    public function updateTransaction(Request $request, Transaction $transaction): JsonResponse
    {
        Gate::authorize('update', $transaction);

        $rules = array_map(fn ($rule) => array_merge(['sometimes'], (array) $rule), $this->transactionRules($request));
        $transaction->update($request->validate($rules));

        return response()->json($transaction->load('category'));
    }

    public function destroyTransaction(Request $request, Transaction $transaction): JsonResponse
    {
        Gate::authorize('delete', $transaction);

        $transaction->delete();
        return response()->json(null, 204);
    }

    /**
     * The category must belong to the same user; a bare `exists` check let a
     * request attach (and then read) someone else's category.
     */
    private function transactionRules(Request $request): array
    {
        return [
            'category_id' => [
                'nullable',
                Rule::exists('expense_categories', 'id')->where('user_id', $request->user()->id),
            ],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'type' => ['required', 'in:income,expense'],
            'transaction_date' => ['required', 'date'],
            'note' => ['nullable', 'string'],
        ];
    }
    
    public function getChartData(Request $request): JsonResponse
    {
        $startDateStr = Carbon::now()->subDays(6)->format('Y-m-d');
        
        $transactions = Transaction::where('user_id', $request->user()->id)
            ->where('transaction_date', '>=', $startDateStr)
            ->get();
            
        $grouped = [];
        foreach ($transactions as $tx) {
            $date = Carbon::parse($tx->transaction_date)->format('Y-m-d');
            $key = $date . '_' . $tx->type;
            if (!isset($grouped[$key])) {
                $grouped[$key] = [
                    'transaction_date' => $date,
                    'type' => $tx->type,
                    'total' => 0
                ];
            }
            $grouped[$key]['total'] += $tx->amount;
        }
        
        return response()->json(array_values($grouped));
    }
}
