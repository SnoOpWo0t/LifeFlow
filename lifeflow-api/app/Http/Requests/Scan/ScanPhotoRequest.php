<?php

namespace App\Http\Requests\Scan;

use Illuminate\Foundation\Http\FormRequest;

class ScanPhotoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Base64 image, ~3 MB at most. The app resizes photos to ~1600px first.
            'image' => ['required', 'string', 'max:4000000', 'regex:/^[A-Za-z0-9+\/]+={0,2}$/'],
            'mime_type' => ['required', 'in:image/jpeg,image/png,image/webp,image/heic,image/heif'],
            // money: receipts and notes -> expenses / income. wishlist: things to buy.
            'target' => ['required', 'in:money,wishlist'],
        ];
    }

    public function messages(): array
    {
        return [
            'image.max' => 'That photo is too large. Try a smaller one.',
            'image.regex' => 'Bad image data.',
            'mime_type.in' => 'Send a JPEG, PNG, WebP or HEIC photo.',
        ];
    }
}
