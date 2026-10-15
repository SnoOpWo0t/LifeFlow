<?php

namespace App\Services;

/**
 * Turns a photo into entries the user can review before saving:
 *  - "money": a receipt (one expense per item, plus extras and a discount) or
 *    the user's own notes listing expenses and income.
 *  - "wishlist": a shopping list or a screenshot of things to buy.
 *
 * Nothing is saved here. Model output is never trusted: every field is
 * clamped to what the database accepts, and dates after today are dropped.
 *
 * Design adapted from the Catalyst app's memo and list scanners.
 */
class PhotoReader
{
    private const TITLE = 255;
    private const NAME = 60;

    public function __construct(private Gemini $gemini)
    {
    }

    /**
     * @param  array{expense: string[], income: string[], wishlist: string[]}  $categories  the user's own names
     * @return array{ok: true, result: array<string, mixed>}|array{ok: false, status: int, error: string}
     */
    public function read(string $image, string $mimeType, string $target, array $categories, string $today): array
    {
        $wishlist = $target === 'wishlist';
        $result = $this->gemini->json(
            system: $wishlist ? $this->wishlistPrompt($categories['wishlist'], $today) : $this->moneyPrompt($categories['expense'], $categories['income'], $today),
            parts: [
                ['inlineData' => ['mimeType' => $mimeType, 'data' => $image]],
                ['text' => 'Read this image.'],
            ],
            schema: $wishlist ? $this->wishlistSchema() : $this->moneySchema(),
            tag: 'scan',
        );

        if (! $result['ok']) {
            return match ($result['reason']) {
                Gemini::BUSY => $this->fail(503, 'The photo reader is busy right now. Try again in a minute.'),
                Gemini::FAILED => $this->fail(502, "The photo reader couldn't process this photo. Try another one."),
                default => $this->fail(502, "The photo reader isn't available. Try again later."),
            };
        }
        $raw = $result['json'];

        if ($wishlist) {
            if (($raw['isList'] ?? false) !== true) {
                return $this->fail(422, "That doesn't look like a shopping list or something to buy.");
            }
            $items = $this->cleanWishlist($raw, $categories['wishlist']);

            return $items
                ? ['ok' => true, 'result' => ['kind' => 'wishlist', 'wishlist' => ['items' => $items]]]
                : $this->fail(422, "Couldn't find any items in this photo. Try a sharper screenshot.");
        }

        if (($raw['kind'] ?? '') === 'notes') {
            $notes = $this->cleanNotes($raw, $categories['expense'], $categories['income'], $today);

            return $notes['entries']
                ? ['ok' => true, 'result' => ['kind' => 'notes', 'notes' => $notes]]
                : $this->fail(422, "Couldn't find any expenses or income in this note. Try a sharper screenshot.");
        }
        if (($raw['kind'] ?? '') !== 'receipt') {
            return $this->fail(422, "That doesn't look like a receipt, a memo or a note of expenses and income.");
        }

        $receipt = $this->cleanReceipt($raw, $categories['expense'], $today);

        return $receipt['items'] || $receipt['extras']
            ? ['ok' => true, 'result' => ['kind' => 'receipt', 'receipt' => $receipt]]
            : $this->fail(422, "Couldn't find any items on this receipt. Try a sharper, closer photo.");
    }

    // ---------------------------------------------------------------- prompts

    private function moneyPrompt(array $expense, array $income, string $today): string
    {
        $expenseList = $expense ? implode(', ', $expense) : 'none yet';
        $incomeList = $income ? implode(', ', $income) : 'none yet';

        return <<<PROMPT
        You read photos and screenshots for a personal money app used mostly in Bangladesh and turn them into entries. Text may be printed, typed or handwritten, in English or Bengali (Bengali digits ০-৯ are numbers). Today is {$today}.

        First decide what the image is (kind):
        - "receipt": a shop receipt, bill or cash memo for one purchase.
        - "notes": the person's own record of their money: a notes app or Notepad screenshot, a handwritten list, a chat message or a spreadsheet listing expenses and/or income.
        - "other": anything else.

        For a receipt, fill merchant, date, items, extras, discount and total, and leave entries empty. Receipts are usually from the last few days, which helps tell similar digits apart in dates.
        - items: every purchased line. name = short item name in English (translate Bengali; keep brand names). amount = the line total actually charged (quantity x unit price), as a plain number.
        - extras: VAT/tax, service charge, delivery, packaging or tips, each with a positive amount. Do not repeat them in items.
        - discount: total discount as a positive number, 0 if none.
        - total: the grand total payable as printed, 0 if unreadable.
        - date: purchase date as YYYY-MM-DD (dates are usually day/month/year), "" if not printed.
        - merchant: shop name in English letters (transliterate Bengali), "" if unknown.
        - item category: the single best match from the expense categories below; if none fits, a short one-word category such as Food or Groceries.
        - Ignore cash given, change returned, subtotals and running totals.

        For notes, fill entries (and date, if the whole note has one date) and leave items and extras empty.
        - One entry per money line, in order. Skip headings, totals, balances and running sums.
        - type: "income" for money received (salary, payment received, a gift, a refund, a "+" amount); "expense" for money spent, the default when unclear.
        - amount: the line's amount as a plain positive number. Ignore "tk", "৳" and other currency marks.
        - name: a short description in English (translate Bengali), e.g. "Lunch" or "Rickshaw to office".
        - category: if the note labels the line or its section with a category, use that label, but when it means the same as one of the categories below for that type, use that category's exact spelling. If the note doesn't label it, choose the best category below for its type. Never invent a category the note doesn't name.
        - date: YYYY-MM-DD when the line or its section has a date (usually day/month; this year unless a year is written), else "".

        Expense categories: {$expenseList}.
        Income categories: {$incomeList}.
        PROMPT;
    }

    private function wishlistPrompt(array $categories, string $today): string
    {
        $categoryList = $categories ? implode(', ', $categories) : 'none yet';

        return <<<PROMPT
        You read screenshots and photos of things a person wants to buy: a shopping list in a notes app, Notepad, a chat or handwriting, or screenshots of products from online shops. Text may be in English or Bengali (Bengali digits ০-৯ are numbers). Today is {$today}.

        Rules:
        - One item per line, bullet or product, in the order they appear. Skip headings, the note's date, app buttons, the status bar and anything that isn't an item.
        - title: the item as a short phrase in English (translate Bengali; keep names, brands, models and quantities, e.g. "Rice 5 kg").
        - note: extra detail from the same line or product (colour, size, seller), "" if none.
        - price: the item's price as a plain number (ignore tk, ৳ and other currency marks; for a product page use the current/discounted price), 0 if none.
        - priority: "high" when marked urgent, important, must-have, starred or with "!"; "low" when marked optional, maybe or someday; otherwise "normal".
        - category: the best match from these wishlist categories: {$categoryList}; if none fits, a short one- or two-word category such as Electronics, Fashion, Books or Groceries.
        - link: a URL shown for the item, "" if none.
        - If the image has no list or product at all, set isList to false and return no items.
        PROMPT;
    }

    // ---------------------------------------------------------------- schemas

    private function moneySchema(): array
    {
        $named = fn (array $extra = []) => [
            'type' => 'ARRAY',
            'items' => [
                'type' => 'OBJECT',
                'properties' => ['name' => ['type' => 'STRING'], 'amount' => ['type' => 'NUMBER']] + $extra,
                'required' => array_merge(['name', 'amount'], array_keys($extra)),
            ],
        ];

        return [
            'type' => 'OBJECT',
            'properties' => [
                'kind' => ['type' => 'STRING', 'enum' => ['receipt', 'notes', 'other']],
                'merchant' => ['type' => 'STRING'],
                'date' => ['type' => 'STRING'],
                'items' => $named(['category' => ['type' => 'STRING']]),
                'extras' => $named(),
                'discount' => ['type' => 'NUMBER'],
                'total' => ['type' => 'NUMBER'],
                'entries' => [
                    'type' => 'ARRAY',
                    'items' => [
                        'type' => 'OBJECT',
                        'properties' => [
                            'type' => ['type' => 'STRING', 'enum' => ['expense', 'income']],
                            'name' => ['type' => 'STRING'],
                            'amount' => ['type' => 'NUMBER'],
                            'category' => ['type' => 'STRING'],
                            'date' => ['type' => 'STRING'],
                        ],
                        'required' => ['type', 'name', 'amount', 'category', 'date'],
                    ],
                ],
            ],
            'required' => ['kind', 'merchant', 'date', 'items', 'extras', 'discount', 'total', 'entries'],
        ];
    }

    private function wishlistSchema(): array
    {
        return [
            'type' => 'OBJECT',
            'properties' => [
                'isList' => ['type' => 'BOOLEAN'],
                'items' => [
                    'type' => 'ARRAY',
                    'items' => [
                        'type' => 'OBJECT',
                        'properties' => [
                            'title' => ['type' => 'STRING'],
                            'note' => ['type' => 'STRING'],
                            'price' => ['type' => 'NUMBER'],
                            'priority' => ['type' => 'STRING', 'enum' => ['low', 'normal', 'high']],
                            'category' => ['type' => 'STRING'],
                            'link' => ['type' => 'STRING'],
                        ],
                        'required' => ['title', 'note', 'price', 'priority', 'category', 'link'],
                    ],
                ],
            ],
            'required' => ['isList', 'items'],
        ];
    }

    // --------------------------------------------------------------- cleaning

    private function cleanReceipt(array $raw, array $expense, string $today): array
    {
        return [
            'merchant' => $this->text($raw['merchant'] ?? null, self::TITLE),
            'date' => $this->day($raw['date'] ?? null, $today),
            'items' => collect($this->list($raw['items'] ?? null, 80))
                ->map(fn ($item) => [
                    'name' => $this->text($item['name'] ?? null, self::TITLE) ?: 'Item',
                    'amount' => $this->money($item['amount'] ?? null),
                ] + $this->category($item['category'] ?? null, $expense))
                ->filter(fn ($item) => $item['amount'] > 0)
                ->values()
                ->all(),
            'extras' => collect($this->list($raw['extras'] ?? null, 20))
                ->map(fn ($extra) => [
                    'name' => $this->text($extra['name'] ?? null, self::NAME) ?: 'Extra',
                    'amount' => $this->money($extra['amount'] ?? null),
                ])
                ->filter(fn ($extra) => $extra['amount'] > 0)
                ->values()
                ->all(),
            'discount' => $this->money($raw['discount'] ?? null),
            'total' => $this->money($raw['total'] ?? null),
        ];
    }

    private function cleanNotes(array $raw, array $expense, array $income, string $today): array
    {
        return [
            'date' => $this->day($raw['date'] ?? null, $today),
            'entries' => collect($this->list($raw['entries'] ?? null, 100))
                ->map(function ($entry) use ($expense, $income, $today) {
                    $type = ($entry['type'] ?? null) === 'income' ? 'income' : 'expense';

                    return [
                        'type' => $type,
                        'name' => $this->text($entry['name'] ?? null, self::TITLE),
                        'amount' => $this->money($entry['amount'] ?? null),
                    ] + $this->category($entry['category'] ?? null, $type === 'income' ? $income : $expense)
                      + ['date' => $this->day($entry['date'] ?? null, $today)];
                })
                ->filter(fn ($entry) => $entry['amount'] > 0)
                ->map(function ($entry) {
                    $entry['name'] = $entry['name'] ?: ($entry['category'] ?: 'Entry');

                    return $entry;
                })
                ->values()
                ->all(),
        ];
    }

    private function cleanWishlist(array $raw, array $categories): array
    {
        return collect($this->list($raw['items'] ?? null, 100))
            ->map(function ($item) use ($categories) {
                $link = $this->text($item['link'] ?? null, 2048);
                $category = $this->category($item['category'] ?? null, $categories);

                return [
                    'title' => $this->text($item['title'] ?? null, self::TITLE),
                    'note' => $this->text($item['note'] ?? null, 1000),
                    'price' => $this->money($item['price'] ?? null),
                    'priority' => in_array($item['priority'] ?? null, ['low', 'high'], true) ? $item['priority'] : 'normal',
                    'category' => $category['category'],
                    'link' => preg_match('#^https?://#i', $link) ? $link : '',
                ];
            })
            ->filter(fn ($item) => $item['title'] !== '')
            ->values()
            ->all();
    }

    /**
     * The user's own spelling when the name matches one of their categories
     * (case-insensitive); otherwise the label becomes a new category.
     *
     * @return array{category: string, new_category: bool}
     */
    private function category(mixed $label, array $existing): array
    {
        $label = $this->text($label, self::NAME);
        $match = collect($existing)->first(fn ($name) => mb_strtolower($name) === mb_strtolower($label));

        if ($match !== null) {
            return ['category' => $match, 'new_category' => false];
        }
        if ($label === '') {
            return ['category' => '', 'new_category' => false];
        }

        return ['category' => mb_strtoupper(mb_substr($label, 0, 1)).mb_substr($label, 1), 'new_category' => true];
    }

    private function money(mixed $value): float
    {
        return is_numeric($value) && $value > 0 && $value < 1e10 ? round((float) $value, 2) : 0.0;
    }

    private function text(mixed $value, int $max): string
    {
        return is_string($value) ? mb_substr(trim(preg_replace('/\s+/u', ' ', $value)), 0, $max) : '';
    }

    /** @return array<int, array<string, mixed>> */
    private function list(mixed $value, int $max): array
    {
        return is_array($value) ? array_slice(array_values(array_filter($value, 'is_array')), 0, $max) : [];
    }

    /** A real date, not after today (a later date is a misread), else "". */
    private function day(mixed $value, string $today): string
    {
        $date = $this->text($value, 10);
        if (! preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) || ! checkdate((int) substr($date, 5, 2), (int) substr($date, 8, 2), (int) substr($date, 0, 4))) {
            return '';
        }

        return $date <= $today ? $date : '';
    }

    private function fail(int $status, string $error): array
    {
        return ['ok' => false, 'status' => $status, 'error' => $error];
    }
}
