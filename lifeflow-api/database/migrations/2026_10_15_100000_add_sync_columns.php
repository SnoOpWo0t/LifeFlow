<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Offline-first sync (POST /sync). Every synced row gets:
 *  - uuid: the id the app gives it on the phone, before the server ever sees it
 *  - client_updated_at: when it was last edited (decides which edit wins)
 *  - deleted_at: deletes become tombstones so other devices learn about them
 */
return new class extends Migration
{
    private const TABLES = ['tasks', 'expense_categories', 'transactions', 'habits', 'habit_logs', 'wishlist_items'];

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            Schema::table($table, function (Blueprint $t) {
                $t->string('uuid', 64)->nullable()->unique();
                $t->timestamp('client_updated_at', 3)->nullable();
                $t->softDeletes();
            });
        }

        // Existing rows: random ids, except habit logs, whose id is derived from
        // the habit and day so the same check-in made on two devices is one row.
        foreach (array_diff(self::TABLES, ['habit_logs']) as $table) {
            DB::table($table)->whereNull('uuid')->orderBy('id')->chunkById(500, function ($rows) use ($table) {
                foreach ($rows as $row) {
                    DB::table($table)->where('id', $row->id)->update([
                        'uuid' => (string) Str::uuid(),
                        'client_updated_at' => $row->updated_at,
                    ]);
                }
            });
        }

        DB::table('habit_logs')->whereNull('uuid')->orderBy('id')->chunkById(500, function ($logs) {
            $habits = DB::table('habits')->whereIn('id', $logs->pluck('habit_id'))->pluck('uuid', 'id');
            foreach ($logs as $log) {
                DB::table('habit_logs')->where('id', $log->id)->update([
                    'uuid' => $habits[$log->habit_id].'_'.substr((string) $log->completed_date, 0, 10),
                    'client_updated_at' => $log->updated_at,
                ]);
            }
        });

        Schema::table('tasks', fn (Blueprint $t) => $t->index(['user_id', 'updated_at']));
        Schema::table('expense_categories', fn (Blueprint $t) => $t->index(['user_id', 'updated_at']));
        Schema::table('transactions', fn (Blueprint $t) => $t->index(['user_id', 'updated_at']));
        Schema::table('habits', fn (Blueprint $t) => $t->index(['user_id', 'updated_at']));
        Schema::table('wishlist_items', fn (Blueprint $t) => $t->index(['user_id', 'updated_at']));
    }

    public function down(): void
    {
        foreach (self::TABLES as $table) {
            Schema::table($table, function (Blueprint $t) use ($table) {
                if ($table !== 'habit_logs') {
                    $t->dropIndex(['user_id', 'updated_at']);
                }
                $t->dropUnique(['uuid']);
                $t->dropColumn(['uuid', 'client_updated_at', 'deleted_at']);
            });
        }
    }
};
