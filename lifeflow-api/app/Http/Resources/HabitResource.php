<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HabitResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'color_hex' => $this->color_hex,
            'current_streak' => $this->current_streak,
            'longest_streak' => $this->longest_streak,
            'logs' => HabitLogResource::collection($this->whenLoaded('logs')),
            'created_at' => $this->created_at,
        ];
    }
}
