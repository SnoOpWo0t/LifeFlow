<?php

namespace App\Http\Requests\Expenses;

/** Same rules as creating, but every field is optional. Ownership: TransactionPolicy. */
class UpdateTransactionRequest extends StoreTransactionRequest
{
    public function rules(): array
    {
        return array_map(
            fn ($rule) => array_merge(['sometimes'], (array) $rule),
            parent::rules(),
        );
    }
}
