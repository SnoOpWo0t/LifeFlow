<?php

namespace App\Http\Controllers;

use App\Models\Bill;
use App\Models\ExpenseCategory;
use App\Models\Transaction;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BillController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $bills = Bill::where('user_id', $request->user()->id)
            ->with('category')
            ->orderBy('due_date', 'asc')
            ->get();

        return response()->json($bills);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'category_id' => ['nullable', 'exists:expense_categories,id'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'due_date' => ['required', 'date'],
            'frequency' => ['required', 'in:one_time,weekly,monthly,quarterly,yearly'],
            'account' => ['required', 'in:cash,bkash,nagad,bank'],
            'is_paid' => ['nullable', 'boolean'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $bill = Bill::create([
            'user_id' => $request->user()->id,
            ...$validated,
        ]);

        return response()->json($bill->load('category'), 201);
    }

    public function show(Request $request, Bill $bill): JsonResponse
    {
        if ($bill->user_id !== $request->user()->id) {
            abort(403);
        }

        return response()->json($bill->load('category'));
    }

    public function update(Request $request, Bill $bill): JsonResponse
    {
        if ($bill->user_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'category_id' => ['nullable', 'exists:expense_categories,id'],
            'amount' => ['sometimes', 'numeric', 'min:0.01'],
            'due_date' => ['sometimes', 'date'],
            'frequency' => ['sometimes', 'in:one_time,weekly,monthly,quarterly,yearly'],
            'account' => ['sometimes', 'in:cash,bkash,nagad,bank'],
            'is_paid' => ['sometimes', 'boolean'],
            'last_paid_at' => ['nullable', 'date'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $bill->update($validated);

        return response()->json($bill->load('category'));
    }

    public function destroy(Request $request, Bill $bill): JsonResponse
    {
        if ($bill->user_id !== $request->user()->id) {
            abort(403);
        }

        $bill->delete();

        return response()->json(['message' => 'Bill deleted successfully']);
    }

    /**
     * Mark bill as paid.
     * Optionally creates an expense transaction.
     * If bill is recurring, advances due_date to the next cycle.
     */
    public function pay(Request $request, Bill $bill): JsonResponse
    {
        if ($bill->user_id !== $request->user()->id) {
            abort(403);
        }

        $today = Carbon::today();
        $bill->last_paid_at = $today;

        // Create transaction if requested or default true
        $createTransaction = $request->boolean('create_transaction', true);
        if ($createTransaction) {
            Transaction::create([
                'user_id' => $bill->user_id,
                'category_id' => $bill->category_id,
                'amount' => $bill->amount,
                'type' => 'expense',
                'account' => $bill->account,
                'transaction_date' => $today->toDateString(),
                'note' => 'Bill payment: ' . $bill->title,
            ]);
        }

        if ($bill->frequency === 'one_time') {
            $bill->is_paid = true;
        } else {
            // Advance due_date
            $dueDate = Carbon::parse($bill->due_date);
            $bill->due_date = match ($bill->frequency) {
                'weekly' => $dueDate->addWeek(),
                'quarterly' => $dueDate->addMonths(3),
                'yearly' => $dueDate->addYear(),
                default => $dueDate->addMonth(), // monthly
            };
            $bill->is_paid = false;
        }

        $bill->save();

        return response()->json([
            'message' => 'Bill marked as paid',
            'bill' => $bill->load('category'),
        ]);
    }
}
