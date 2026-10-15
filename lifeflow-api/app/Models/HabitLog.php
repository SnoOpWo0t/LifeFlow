<?php

namespace App\Models;

use App\Models\Concerns\Syncable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class HabitLog extends Model
{
    use HasFactory, Syncable;

    protected $fillable = [
        'habit_id',
        'completed_date'
    ];

    public function habit(): BelongsTo
    {
        return $this->belongsTo(Habit::class)->withTrashed();
    }

    /** One row per habit and day on every device: "<habit uuid>_<YYYY-MM-DD>". */
    protected function newSyncUuid(): string
    {
        return $this->habit->uuid.'_'.substr((string) $this->completed_date, 0, 10);
    }
}
