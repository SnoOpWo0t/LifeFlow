<?php

namespace App\Http\Controllers;

use App\Models\SavingsGoal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SavingsGoalController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $goals = SavingsGoal::where('user_id', $request->user()->id)
            ->orderBy('is_completed', 'asc')
            ->orderBy('target_date', 'asc')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json($goals);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'target_amount' => ['required', 'numeric', 'min:0.01'],
            'saved_amount' => ['nullable', 'numeric', 'min:0'],
            'target_date' => ['nullable', 'date'],
            'category' => ['nullable', 'string', 'max:60'],
            'color_hex' => ['nullable', 'string', 'max:7'],
            'is_completed' => ['nullable', 'boolean'],
        ]);

        $goal = SavingsGoal::create([
            'user_id' => $request->user()->id,
            ...$validated,
        ]);

        return response()->json($goal, 201);
    }

    public function show(Request $request, SavingsGoal $savingsGoal): JsonResponse
    {
        if ($savingsGoal->user_id !== $request->user()->id) {
            abort(403);
        }

        return response()->json($savingsGoal);
    }

    public function update(Request $request, SavingsGoal $savingsGoal): JsonResponse
    {
        if ($savingsGoal->user_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'target_amount' => ['sometimes', 'numeric', 'min:0.01'],
            'saved_amount' => ['sometimes', 'numeric', 'min:0'],
            'target_date' => ['nullable', 'date'],
            'category' => ['nullable', 'string', 'max:60'],
            'color_hex' => ['nullable', 'string', 'max:7'],
            'is_completed' => ['sometimes', 'boolean'],
        ]);

        $savingsGoal->update($validated);

        if (isset($validated['saved_amount']) || isset($validated['target_amount'])) {
            if ($savingsGoal->saved_amount >= $savingsGoal->target_amount) {
                $savingsGoal->is_completed = true;
                $savingsGoal->save();
            }
        }

        return response()->json($savingsGoal);
    }

    public function contribute(Request $request, SavingsGoal $savingsGoal): JsonResponse
    {
        if ($savingsGoal->user_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'amount' => ['required', 'numeric'],
        ]);

        $newAmount = max(0, (float)$savingsGoal->saved_amount + (float)$validated['amount']);
        $savingsGoal->saved_amount = $newAmount;
        if ($savingsGoal->saved_amount >= $savingsGoal->target_amount) {
            $savingsGoal->is_completed = true;
        } else {
            $savingsGoal->is_completed = false;
        }
        $savingsGoal->save();

        return response()->json([
            'message' => 'Savings goal contribution recorded',
            'goal' => $savingsGoal,
        ]);
    }

    public function destroy(Request $request, SavingsGoal $savingsGoal): JsonResponse
    {
        if ($savingsGoal->user_id !== $request->user()->id) {
            abort(403);
        }

        $savingsGoal->delete();

        return response()->json(['message' => 'Savings goal deleted successfully']);
    }
}
