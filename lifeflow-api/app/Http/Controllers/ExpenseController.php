<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Models\ExpenseCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
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
        $validated = $request->validate([
            'category_id' => 'nullable|exists:expense_categories,id',
            'amount' => 'required|numeric|min:0.01',
            'type' => 'required|in:income,expense',
            'transaction_date' => 'required|date',
            'note' => 'nullable|string'
        ]);

        $transaction = Transaction::create(array_merge($validated, ['user_id' => $request->user()->id]));
        return response()->json($transaction->load('category'), 201);
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
