<?php

namespace App\Http\Requests\Profile;

use Illuminate\Foundation\Http\FormRequest;

class ExportDataRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // json: everything in the account. csv: transactions, for spreadsheets.
            'format' => 'sometimes|in:json,csv',
        ];
    }
}
