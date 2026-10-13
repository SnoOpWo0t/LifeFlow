<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\URL;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'avatar_url' => self::avatarUrl($this->avatar_path),
            'preferences' => $this->preferences,
            'timezone' => $this->timezone,
            'created_at' => $this->created_at,
        ];
    }

    /**
     * Profile photos are only reachable through a signed, expiring link.
     * The expiry is rounded to the day so the URL (and the browser's cached
     * image) stays the same across requests made on the same day.
     */
    public static function avatarUrl(?string $path): ?string
    {
        if (! $path) {
            return null;
        }

        return URL::temporarySignedRoute(
            'avatar.show',
            now()->startOfDay()->addDays(8),
            ['filename' => $path],
        );
    }
}
