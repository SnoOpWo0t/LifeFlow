<?php

namespace App\Http\Controllers;

use App\Http\Requests\Insights\InsightRequest;
use App\Models\AiInsight;
use App\Services\Gemini;
use App\Services\InsightWriter;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\RateLimiter;

/**
 * AI summaries of a week or month. GET returns the saved summary (no AI call);
 * POST writes a fresh one with Gemini, saves it and counts toward a daily limit.
 */
class InsightController extends Controller
{
    public function show(InsightRequest $request, Gemini $gemini, InsightWriter $writer): JsonResponse
    {
        [$user, $period, $from, $to] = $this->scope($request);
        $insight = $user->aiInsights()->where('period', $period)->whereDate('period_start', $from)->first();

        return response()->json($this->payload($writer, $user, $period, $from, $to, $insight, $gemini->configured()));
    }

    public function generate(InsightRequest $request, Gemini $gemini, InsightWriter $writer): JsonResponse
    {
        if (! $gemini->configured()) {
            return response()->json(['message' => "AI summaries aren't set up on the server yet (GEMINI_API_KEY)."], 503);
        }

        [$user, $period, $from, $to] = $this->scope($request);
        $limit = (int) config('services.gemini.daily_summaries', 20);
        $key = "insights:{$user->id}";
        if (RateLimiter::tooManyAttempts($key, $limit)) {
            return response()->json(['message' => "You've made {$limit} summaries today. Try again tomorrow."], 429);
        }
        RateLimiter::hit($key, 24 * 60 * 60);

        $result = $writer->write($user, $period, $from, $to);
        if (! $result['ok']) {
            return response()->json(['message' => $result['error']], $result['status']);
        }

        $insight = AiInsight::updateOrCreate(
            ['user_id' => $user->id, 'period' => $period, 'period_start' => $from->toDateString()],
            ['content' => $result['content']],
        );
        $insight->touch(); // a regenerated summary is newer than the data it read

        return response()->json($this->payload($writer, $user, $period, $from, $to, $insight, true));
    }

    /** @return array{0: \App\Models\User, 1: string, 2: Carbon, 3: Carbon} */
    private function scope(InsightRequest $request): array
    {
        $user = $request->user();
        $period = $request->validated('period');
        $day = $request->filled('date') ? Carbon::parse($request->validated('date')) : $user->localNow();
        [$from, $to] = InsightWriter::window($period, $day);

        return [$user, $period, $from, $to];
    }

    private function payload(InsightWriter $writer, $user, string $period, Carbon $from, Carbon $to, ?AiInsight $insight, bool $configured): array
    {
        $lastChange = $insight ? $writer->lastChange($user, $from, $to) : null;

        return [
            'period' => $period,
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'configured' => $configured,
            'insight' => $insight ? $insight->content + ['generated_at' => $insight->updated_at->toIso8601String()] : null,
            // New data since the summary was written: offer to refresh it.
            'stale' => $insight !== null && $lastChange !== null && $lastChange->greaterThan($insight->updated_at),
        ];
    }
}
