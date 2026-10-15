<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('savings', function (Blueprint $table) {
            $table->id();
            $table->string('uuid', 64)->nullable()->unique();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->decimal('amount', 12, 2);
            $table->string('type', 20); // 'deposit' or 'withdrawal'
            $table->string('account', 20)->default('cash'); // 'cash', 'bkash', 'nagad', 'bank'
            $table->text('note')->nullable();
            $table->date('transaction_date');
            $table->timestamp('client_updated_at', 3)->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'updated_at']);
            $table->index(['user_id', 'transaction_date']);
            $table->index(['user_id', 'account']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('savings');
    }
};
