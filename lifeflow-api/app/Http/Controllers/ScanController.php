<?php

namespace App\Http\Controllers;

use App\Http\Requests\Scan\ScanPhotoRequest;
use App\Services\Gemini;
use App\Services\PhotoReader;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Reads a photo (receipt, notes screenshot, shopping list) with Gemini and
 * returns what it found for the user to review. Nothing is saved here: the app
 * creates the entries the user keeps through the normal endpoints.
 */
class ScanController extends Controller
{
    public function __invoke(ScanPhotoRequest $request, Gemini $gemini, PhotoReader $reader): JsonResponse
    {
        if (! $gemini->configured()) {
            return $this->fail(503, "Photo scanning isn't set up on the server yet (GEMINI_API_KEY).");
        }

        // Each photo uses the server's Gemini key, so cap photos per user per day.
        $user = $request->user();
        $limit = (int) config('services.gemini.daily_scans', 40);
        $key = "scan:{$user->id}";
        if (RateLimiter::tooManyAttempts($key, $limit)) {
            return $this->fail(429, "You've scanned {$limit} photos today. Try again tomorrow.");
        }
        RateLimiter::hit($key, 24 * 60 * 60);

        $categoryNames = fn (string $type) => $user->expenseCategories()
            ->where('type', $type)->orderBy('name')->limit(60)->pluck('name')->all();

        $result = $reader->read(
            image: $request->validated('image'),
            mimeType: $request->validated('mime_type'),
            target: $request->validated('target'),
            categories: [
                'expense' => $categoryNames('expense'),
                'income' => $categoryNames('income'),
                'wishlist' => $user->wishlistItems()->whereNotNull('category')
                    ->distinct()->orderBy('category')->limit(60)->pluck('category')->all(),
            ],
            today: $user->localNow()->toDateString(),
        );

        return $result['ok']
            ? response()->json($result['result'])
            : $this->fail($result['status'], $result['error']);
    }

    private function fail(int $status, string $error): JsonResponse
    {
        return response()->json(['message' => $error], $status);
    }
}
