<?php

namespace App\Http\Requests\Insights;

use Illuminate\Foundation\Http\FormRequest;

class InsightRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'period' => ['required', 'in:week,month'],
            // Any day inside the period; defaults to the user's today.
            'date' => ['sometimes', 'date_format:Y-m-d'],
        ];
    }
}
