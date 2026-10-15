<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('savings_goals', function (Blueprint $table) {
            $table->id();
            $table->string('uuid', 64)->nullable()->unique();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->decimal('target_amount', 12, 2);
            $table->decimal('saved_amount', 12, 2)->default(0.00);
            $table->date('target_date')->nullable();
            $table->string('category', 60)->nullable();
            $table->string('color_hex', 7)->nullable();
            $table->boolean('is_completed')->default(false);
            $table->timestamp('client_updated_at', 3)->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'updated_at']);
            $table->index(['user_id', 'is_completed']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('savings_goals');
    }
};
