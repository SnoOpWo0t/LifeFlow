<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Habit extends Model
{
    use HasFactory;

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
}
