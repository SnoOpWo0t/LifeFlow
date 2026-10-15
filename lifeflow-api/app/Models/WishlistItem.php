<?php

namespace App\Models;

use App\Models\Concerns\Syncable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WishlistItem extends Model
{
    use HasFactory, Syncable;

    protected $fillable = [
        'user_id',
        'title',
        'note',
        'estimated_price',
        'priority',
        'category',
        'is_purchased',
        'link',
        'sort_order',
    ];

    protected $attributes = [
        'is_purchased' => false,
        'priority' => 'normal',
    ];

    protected $casts = [
        'is_purchased' => 'boolean',
        'estimated_price' => 'decimal:2',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
