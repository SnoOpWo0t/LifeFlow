<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

/**
 * Rows the app keeps offline and syncs (see SyncController). Deletes are soft,
 * so they reach other devices, and every write records when it happened.
 * Rows written by POST /sync carry the device's own edit time instead.
 */
trait Syncable
{
    use SoftDeletes;

    public static function bootSyncable(): void
    {
        static::creating(function ($model) {
            $model->uuid ??= $model->newSyncUuid();
        });

        static::saving(function ($model) {
            if (! $model->isDirty('client_updated_at')) {
                $model->client_updated_at = now();
            }
        });

        // A soft delete updates the row directly, skipping "saving".
        static::softDeleted(function ($model) {
            $model->newQueryWithoutScopes()->whereKey($model->getKey())
                ->update(['client_updated_at' => now()]);
        });
    }

    public function initializeSyncable(): void
    {
        $this->mergeCasts(['client_updated_at' => 'datetime']);
    }

    protected function newSyncUuid(): string
    {
        return (string) Str::uuid();
    }
}
