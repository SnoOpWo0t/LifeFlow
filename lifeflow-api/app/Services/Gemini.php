<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Asks Google Gemini for JSON that follows a schema. The API key is read only
 * here, on the server. Models are tried in order: when one is busy, rate
 * limited or retired, the next one gets the request.
 */
class Gemini
{
    public const BUSY = 'busy';
    public const UNAVAILABLE = 'unavailable';
    public const FAILED = 'failed';

    public function configured(): bool
    {
        return filled(config('services.gemini.key'));
    }

    /**
     * @param  array<int, array<string, mixed>>  $parts  Gemini content parts (text / inlineData)
     * @return array{ok: true, json: array<string, mixed>}|array{ok: false, reason: string}
     */
    public function json(string $system, array $parts, array $schema, string $tag): array
    {
        $deadline = microtime(true) + 52; // stay well inside a 60 s request
        $busy = false;

        foreach ($this->models() as [$model, $thinking]) {
            $left = $deadline - microtime(true);
            if ($left < 4) {
                break;
            }

            $generation = [
                'temperature' => 0,
                'responseMimeType' => 'application/json',
                'responseSchema' => $schema,
            ];
            if ($thinking) {
                $generation['thinkingConfig'] = ['thinkingLevel' => $thinking];
            }

            try {
                $response = Http::withHeaders(['x-goog-api-key' => config('services.gemini.key')])
                    ->timeout((int) min(30, $left))
                    ->post("https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent", [
                        'systemInstruction' => ['parts' => [['text' => $system]]],
                        'contents' => [['role' => 'user', 'parts' => $parts]],
                        'generationConfig' => $generation,
                    ]);
            } catch (ConnectionException) {
                $busy = true; // timed out or network error: try the next model

                continue;
            }

            if (! $response->successful()) {
                if (in_array($response->status(), [404, 429, 500, 502, 503, 504], true)) {
                    $busy = $busy || $response->status() !== 404;

                    continue;
                }
                Log::error("[{$tag}] gemini {$model} {$response->status()}", ['body' => mb_substr($response->body(), 0, 300)]);

                return ['ok' => false, 'reason' => self::FAILED];
            }

            // The answer is the first non-"thought" text part.
            $text = collect($response->json('candidates.0.content.parts', []))
                ->first(fn ($part) => is_string($part['text'] ?? null) && empty($part['thought']))['text'] ?? null;
            $json = is_string($text) ? json_decode($text, true) : null;

            return is_array($json) && ! array_is_list($json)
                ? ['ok' => true, 'json' => $json]
                : ['ok' => false, 'reason' => self::FAILED];
        }

        return ['ok' => false, 'reason' => $busy ? self::BUSY : self::UNAVAILABLE];
    }

    /** @return array<int, array{0: string, 1: ?string}> */
    private function models(): array
    {
        return collect(explode(',', (string) config('services.gemini.models')))
            ->map(fn ($entry) => trim($entry))
            ->filter()
            ->map(function ($entry) {
                [$model, $thinking] = array_pad(explode(':', $entry, 2), 2, null);

                return [rawurlencode($model), $thinking ?: null];
            })
            ->values()
            ->all();
    }
}
