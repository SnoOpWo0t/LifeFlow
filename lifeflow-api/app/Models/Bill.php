<?php

namespace App\Models;

use App\Models\Concerns\Syncable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Bill extends Model
{
    use HasFactory, Syncable;

    protected $fillable = [
        'user_id',
        'category_id',
        'title',
        'amount',
        'due_date',
        'frequency',
        'account',
        'is_paid',
        'last_paid_at',
        'note',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'due_date' => 'date',
        'last_paid_at' => 'date',
        'is_paid' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(ExpenseCategory::class);
    }
}
