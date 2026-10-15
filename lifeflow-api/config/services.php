<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // Photo reader (receipts, notes and shopping-list screenshots). The key
    // stays on the server; the app never sees it. Free key: aistudio.google.com
    'gemini' => [
        'key' => env('GEMINI_API_KEY'),
        // Tried in order; "model:thinkingLevel" sets Gemini's thinking level.
        'models' => env('GEMINI_MODELS', 'gemini-3.5-flash:low,gemini-3.1-flash-lite,gemini-3.5-flash-lite'),
        'daily_scans' => (int) env('GEMINI_DAILY_SCANS', 40),
        'daily_summaries' => (int) env('GEMINI_DAILY_SUMMARIES', 20),
    ],

];
