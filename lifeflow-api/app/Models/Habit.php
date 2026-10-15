<?php

namespace App\Models;

use App\Models\Concerns\Syncable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Habit extends Model
{
    use HasFactory, Syncable;

    protected $fillable = [
        'user_id',
        'name',
        'color_hex',
        'current_streak',
        'longest_streak',
    ];

    public function logs(): HasMany
    {
        return $this->hasMany(HabitLog::class);
    }

    /**
     * Derive streaks from the logs instead of incrementing counters, which
     * drifted whenever a day was missed or a check-in was undone.
     *
     * current_streak: consecutive days ending today, or ending yesterday if
     * today isn't checked yet (the streak is still alive until midnight).
     */
    public function refreshStreaks(Carbon $today): void
    {
        $days = $this->logs()
            ->orderBy('completed_date')
            ->pluck('completed_date')
            ->map(fn ($date) => Carbon::parse($date)->toDateString())
            ->unique()
            ->values();

        $longest = 0;
        $run = 0;
        $previous = null;
        foreach ($days as $day) {
            $continues = $previous !== null
                && Carbon::parse($previous)->addDay()->toDateString() === $day;
            $run = $continues ? $run + 1 : 1;
            $longest = max($longest, $run);
            $previous = $day;
        }

        $logged = $days->flip();
        $cursor = $today->copy();
        if (! $logged->has($cursor->toDateString())) {
            $cursor->subDay();
        }
        $current = 0;
        while ($logged->has($cursor->toDateString())) {
            $current++;
            $cursor->subDay();
        }

        if ($this->current_streak !== $current || $this->longest_streak !== $longest) {
            $this->current_streak = $current;
            $this->longest_streak = $longest;
            // Derived numbers, not an edit: don't make this look like a change to sync.
            static::withoutTimestamps(fn () => $this->saveQuietly());
        }
    }
}
