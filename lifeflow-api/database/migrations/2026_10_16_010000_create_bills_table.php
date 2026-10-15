<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('bills', function (Blueprint $table) {
            $table->id();
            $table->string('uuid', 64)->nullable()->unique();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->nullable()->constrained('expense_categories')->nullOnDelete();
            $table->string('title');
            $table->decimal('amount', 12, 2);
            $table->date('due_date');
            $table->string('frequency', 20)->default('monthly'); // 'monthly', 'weekly', 'yearly', 'one_time'
            $table->string('account', 20)->default('bank'); // 'cash', 'bkash', 'nagad', 'bank'
            $table->boolean('is_paid')->default(false);
            $table->date('last_paid_at')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('client_updated_at', 3)->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'updated_at']);
            $table->index(['user_id', 'due_date']);
            $table->index(['user_id', 'is_paid']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bills');
    }
};
