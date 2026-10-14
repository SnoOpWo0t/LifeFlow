<?php

namespace App\Http\Requests\Wishlist;

use Illuminate\Foundation\Http\FormRequest;

class StoreWishlistItemRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'note' => ['nullable', 'string'],
            'estimated_price' => ['nullable', 'numeric', 'min:0'],
            'priority' => ['nullable', 'in:low,normal,high'],
            'category' => ['nullable', 'string', 'max:60'],
            'is_purchased' => ['nullable', 'boolean'],
            'link' => ['nullable', 'string', 'max:2048'],
            'sort_order' => ['nullable', 'integer'],
        ];
    }
}
