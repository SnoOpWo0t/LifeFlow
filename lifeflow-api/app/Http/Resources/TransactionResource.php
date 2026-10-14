<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'category' => new CategoryResource($this->whenLoaded('category')),
            'amount' => $this->amount,
            'type' => $this->type,
            'account' => $this->account ?? 'cash',
            'transaction_date' => $this->transaction_date,
            'note' => $this->note,
            'created_at' => $this->created_at,
        ];
    }
}
