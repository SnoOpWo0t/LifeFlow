<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The app sends its IANA timezone in an X-Timezone header. Remember it on the
 * signed-in user so date logic ("today", "this week") uses their local day.
 */
class UseClientTimezone
{
    public function handle(Request $request, Closure $next): Response
    {
        $timezone = $request->header('X-Timezone');
        $user = $request->user('sanctum');

        if ($user && $timezone && $timezone !== $user->timezone
            && in_array($timezone, timezone_identifiers_list(), true)) {
            $user->forceFill(['timezone' => $timezone])->saveQuietly();
        }

        return $next($request);
    }
}
