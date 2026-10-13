<?php

namespace App\Http\Requests\Expenses;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreTransactionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Scoped to the user: a bare `exists` check let a request attach
            // (and then read) someone else's category.
            'category_id' => [
                'nullable',
                Rule::exists('expense_categories', 'id')->where('user_id', $this->user()->id),
            ],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'type' => ['required', 'in:income,expense'],
            'transaction_date' => ['required', 'date'],
            'note' => ['nullable', 'string'],
        ];
    }
}
