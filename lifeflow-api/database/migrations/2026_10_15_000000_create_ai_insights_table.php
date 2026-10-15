<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Saved AI summaries: one per user, period type and period start, so a
     * summary is written once and shown again without calling the AI.
     */
    public function up(): void
    {
        Schema::create('ai_insights', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('period', 10); // week | month
            $table->date('period_start');
            $table->json('content');      // headline, summary, highlights, suggestions
            $table->timestamps();
            $table->unique(['user_id', 'period', 'period_start']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_insights');
    }
};
