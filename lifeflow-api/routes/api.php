<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CalendarController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\TaskController;
use App\Http\Controllers\ExpenseController;
use App\Http\Controllers\HabitController;
use App\Http\Controllers\InsightController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ScanController;
use App\Http\Controllers\WishlistController;

Route::prefix('v1')->group(function () {
    // 10 attempts per minute per IP slows down password guessing.
    Route::middleware('throttle:10,1')->group(function () {
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/login', [AuthController::class, 'login'])->name('login');
    });

    // Profile photos: only reachable through signed, expiring links.
    Route::get('/avatar/{filename}', [ProfileController::class, 'showAvatar'])
        ->middleware('signed')
        ->name('avatar.show');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/user', [AuthController::class, 'user']);
        Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
        Route::get('/calendar', [CalendarController::class, 'month']);
        Route::get('/calendar/day', [CalendarController::class, 'day']);

        // AI photo reader: receipts, notes and shopping lists -> entries to review.
        Route::post('/scan', ScanController::class);

        // AI summaries: GET = saved summary (no AI call), POST = write a new one.
        Route::get('/insights', [InsightController::class, 'show']);
        Route::post('/insights', [InsightController::class, 'generate']);
        Route::get('/analytics/weekly', [App\Http\Controllers\AnalyticsController::class, 'weekly']);
        
        Route::apiResource('tasks', TaskController::class);
        
        Route::get('/categories', [ExpenseController::class, 'getCategories']);
        Route::post('/categories', [ExpenseController::class, 'storeCategory']);
        Route::put('/categories/{category}', [ExpenseController::class, 'updateCategory']);
        Route::delete('/categories/{category}', [ExpenseController::class, 'destroyCategory']);
        Route::get('/transactions', [ExpenseController::class, 'getTransactions']);
        Route::post('/transactions', [ExpenseController::class, 'storeTransaction']);
        Route::put('/transactions/{transaction}', [ExpenseController::class, 'updateTransaction']);
        Route::delete('/transactions/{transaction}', [ExpenseController::class, 'destroyTransaction']);
        Route::get('/transactions/chart', [ExpenseController::class, 'getChartData']);
        Route::get('/transactions/by-category', [ExpenseController::class, 'spendingByCategory']);
        
        Route::apiResource('habits', HabitController::class)->except(['show']);
        Route::post('/habits/{habit}/toggle', [HabitController::class, 'toggle']);

        Route::apiResource('wishlist', WishlistController::class)->parameters(['wishlist' => 'wishlistItem']);
        Route::post('/wishlist/reorder', [WishlistController::class, 'reorder']);
        
        // Profile & Settings Routes
        Route::post('/profile/avatar', [ProfileController::class, 'updateAvatar']);
        Route::put('/profile/settings', [ProfileController::class, 'updateSettings']);
        Route::delete('/profile', [ProfileController::class, 'destroy']);
        Route::get('/profile/export', [ProfileController::class, 'export']);
    });
});
