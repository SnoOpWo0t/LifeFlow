<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\TaskController;
use App\Http\Controllers\ExpenseController;
use App\Http\Controllers\HabitController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Response;

Route::prefix('v1')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);

    Route::get('/avatar/{filename}', function ($filename) {
        $path = storage_path('app/public/avatars/' . $filename);
        if (!File::exists($path)) {
            abort(404);
        }
        $file = File::get($path);
        $type = File::mimeType($path);
        $response = Response::make($file, 200);
        $response->header("Content-Type", $type);
        $response->header("Access-Control-Allow-Origin", "*");
        return $response;
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/user', [AuthController::class, 'user']);
        Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
        Route::get('/analytics/weekly', [App\Http\Controllers\AnalyticsController::class, 'weekly']);
        
        Route::apiResource('tasks', TaskController::class);
        
        Route::get('/categories', [ExpenseController::class, 'getCategories']);
        Route::post('/categories', [ExpenseController::class, 'storeCategory']);
        Route::get('/transactions', [ExpenseController::class, 'getTransactions']);
        Route::post('/transactions', [ExpenseController::class, 'storeTransaction']);
        Route::get('/transactions/chart', [ExpenseController::class, 'getChartData']);
        
        Route::apiResource('habits', HabitController::class)->except(['update', 'show']);
        Route::post('/habits/{habit}/toggle', [HabitController::class, 'toggle']);
        
        // Profile & Settings Routes
        Route::post('/profile/avatar', [ProfileController::class, 'updateAvatar']);
        Route::put('/profile/settings', [ProfileController::class, 'updateSettings']);
    });
});
