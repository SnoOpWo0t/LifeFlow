<?php

namespace App\Models;

use App\Models\Concerns\Syncable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ExpenseCategory extends Model
{
    use HasFactory, Syncable;

    protected $fillable = [
        'user_id',
        'name',
        'type',
        'color_hex'
    ];
}
