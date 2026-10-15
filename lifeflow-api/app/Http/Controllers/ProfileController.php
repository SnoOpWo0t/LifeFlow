<?php

namespace App\Http\Controllers;

use App\Http\Requests\Profile\DeleteAccountRequest;
use App\Http\Requests\Profile\ExportDataRequest;
use App\Http\Requests\Profile\UpdateAvatarRequest;
use App\Http\Requests\Profile\UpdateSettingsRequest;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\HabitResource;
use App\Http\Resources\TaskResource;
use App\Http\Resources\TransactionResource;
use App\Http\Resources\UserResource;
use App\Http\Resources\WishlistItemResource;
use App\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ProfileController extends Controller
{
    public function updateAvatar(UpdateAvatarRequest $request): JsonResponse
    {
        $user = $request->user();

        if ($user->avatar_path) {
            Storage::disk('public')->delete('avatars/' . $user->avatar_path);
        }

        $path = $request->file('avatar')->store('avatars', 'public');
        $user->avatar_path = basename($path);
        $user->save();

        return response()->json(['avatar_url' => UserResource::avatarUrl($user->avatar_path)]);
    }

    /**
     * Serves a profile photo. The route requires a valid signature (see
     * UserResource::avatarUrl), so photos can't be fetched by guessing or
     * re-using an old link after it expires.
     */
    public function showAvatar(string $filename): Response
    {
        $path = 'avatars/' . basename($filename);
        abort_unless(Storage::disk('public')->exists($path), 404);

        return Storage::disk('public')->response($path, null, [
            'Cache-Control' => 'private, max-age=86400',
            'Access-Control-Allow-Origin' => '*',
        ]);
    }

    public function updateSettings(UpdateSettingsRequest $request): JsonResponse
    {
        $user = $request->user();
        $user->preferences = array_merge($user->preferences ?? [], $request->validated('preferences'));
        $user->save();

        return response()->json(['preferences' => $user->preferences]);
    }

    /**
     * Download everything in the account. json (default): profile, settings,
     * tasks, habits with full check-in history, categories and transactions.
     * csv: transactions only, ready for a spreadsheet.
     */
    public function export(ExportDataRequest $request): Response
    {
        $user = $request->user();
        $stamp = $user->localNow()->format('Y-m-d');

        if ($request->validated('format') === 'csv') {
            return new StreamedResponse(function () use ($user) {
                $out = fopen('php://output', 'w');
                fputcsv($out, ['date', 'type', 'amount', 'category', 'note']);
                Transaction::with('category')
                    ->where('user_id', $user->id)
                    ->orderBy('transaction_date')
                    ->each(function (Transaction $tx) use ($out) {
                        fputcsv($out, [
                            substr((string) $tx->transaction_date, 0, 10),
                            $tx->type,
                            $tx->amount,
                            $tx->category?->name ?? '',
                            $tx->note ?? '',
                        ]);
                    });
                fclose($out);
            }, 200, [
                'Content-Type' => 'text/csv; charset=UTF-8',
                'Content-Disposition' => "attachment; filename=\"lifeflow-transactions-{$stamp}.csv\"",
            ]);
        }

        $data = [
            'exported_at' => now()->toIso8601String(),
            'profile' => [
                'name' => $user->name,
                'email' => $user->email,
                'timezone' => $user->timezone,
                'created_at' => $user->created_at,
            ],
            'preferences' => $user->preferences ?? (object) [],
            'tasks' => TaskResource::collection($user->tasks()->get()),
            'habits' => HabitResource::collection($user->habits()->with('logs')->get()),
            'categories' => CategoryResource::collection($user->expenseCategories()->get()),
            'transactions' => TransactionResource::collection(
                Transaction::with('category')->where('user_id', $user->id)->orderBy('transaction_date')->get()
            ),
            'wishlist' => WishlistItemResource::collection($user->wishlistItems()->get()),
            'ai_summaries' => $user->aiInsights()->orderBy('period_start')->get(['period', 'period_start', 'content', 'updated_at']),
        ];

        return response()->json($data, 200, [
            'Content-Disposition' => "attachment; filename=\"lifeflow-export-{$stamp}.json\"",
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    }

    /**
     * Permanently delete the account. Every user-owned table cascades on
     * delete, so tasks, habits, categories and transactions go with it.
     */
    public function destroy(DeleteAccountRequest $request): JsonResponse
    {
        $user = $request->user();
        if ($user->avatar_path) {
            Storage::disk('public')->delete('avatars/' . $user->avatar_path);
        }
        $user->tokens()->delete();
        $user->delete();

        return response()->json(null, 204);
    }
}
