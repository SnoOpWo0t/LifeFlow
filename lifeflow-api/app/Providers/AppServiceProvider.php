<?php

namespace App\Providers;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Single resources return the object itself (no {"data": ...} wrapper),
        // matching the JSON shape the Flutter app has always used. Paginated
        // lists still include "data", "links" and "meta".
        JsonResource::withoutWrapping();
    }
}
