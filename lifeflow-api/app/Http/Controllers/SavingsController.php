<?php

namespace App\Http\Controllers;

use App\Models\Saving;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SavingsController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $savings = Saving::where('user_id', $request->user()->id)
            ->orderBy('transaction_date', 'desc')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json($savings);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
            'type' => ['required', 'in:deposit,withdrawal'],
            'account' => ['required', 'in:cash,bkash,nagad,bank'],
            'transaction_date' => ['required', 'date'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $saving = Saving::create([
            'user_id' => $request->user()->id,
            ...$validated,
        ]);

        return response()->json($saving, 201);
    }

    public function show(Request $request, Saving $saving): JsonResponse
    {
        if ($saving->user_id !== $request->user()->id) {
            abort(403);
        }

        return response()->json($saving);
    }

    public function update(Request $request, Saving $saving): JsonResponse
    {
        if ($saving->user_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'amount' => ['sometimes', 'numeric', 'min:0.01'],
            'type' => ['sometimes', 'in:deposit,withdrawal'],
            'account' => ['sometimes', 'in:cash,bkash,nagad,bank'],
            'transaction_date' => ['sometimes', 'date'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $saving->update($validated);

        return response()->json($saving);
    }

    public function destroy(Request $request, Saving $saving): JsonResponse
    {
        if ($saving->user_id !== $request->user()->id) {
            abort(403);
        }

        $saving->delete();

        return response()->json(['message' => 'Savings entry deleted successfully']);
    }

    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();
        $accounts = ['cash', 'bkash', 'nagad', 'bank'];
        $balances = [];
        $totalSavings = 0.0;
        $totalDeposits = 0.0;
        $totalWithdrawals = 0.0;

        foreach ($accounts as $account) {
            $dep = (float) Saving::where('user_id', $user->id)
                ->where('account', $account)
                ->where('type', 'deposit')
                ->sum('amount');

            $with = (float) Saving::where('user_id', $user->id)
                ->where('account', $account)
                ->where('type', 'withdrawal')
                ->sum('amount');

            $net = $dep - $with;
            $balances[$account] = round($net, 2);
            $totalSavings += $net;
            $totalDeposits += $dep;
            $totalWithdrawals += $with;
        }

        return response()->json([
            'total_savings' => round($totalSavings, 2),
            'total_deposits' => round($totalDeposits, 2),
            'total_withdrawals' => round($totalWithdrawals, 2),
            'by_account' => $balances,
        ]);
    }
}
