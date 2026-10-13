<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Store only the avatar's file name. The public URL used to be saved, which
     * made photos reachable forever by anyone with the link; the API now hands
     * out signed, expiring links built from this path instead.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_path')->nullable();
        });

        DB::table('users')->whereNotNull('avatar_url')->orderBy('id')->each(function ($user) {
            DB::table('users')->where('id', $user->id)->update([
                'avatar_path' => basename(parse_url($user->avatar_url, PHP_URL_PATH) ?? ''),
            ]);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('avatar_url');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_url')->nullable();
        });

        DB::table('users')->whereNotNull('avatar_path')->orderBy('id')->each(function ($user) {
            DB::table('users')->where('id', $user->id)->update([
                'avatar_url' => url('/api/v1/avatar/' . $user->avatar_path),
            ]);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('avatar_path');
        });
    }
};
