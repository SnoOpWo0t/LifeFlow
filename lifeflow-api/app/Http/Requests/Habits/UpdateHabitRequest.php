<?php

namespace App\Http\Requests\Habits;

use Illuminate\Foundation\Http\FormRequest;

/** Rename / recolour. Ownership is checked by HabitPolicy. */
class UpdateHabitRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => 'sometimes|required|string|max:255',
            'color_hex' => 'nullable|string|max:7',
        ];
    }
}
