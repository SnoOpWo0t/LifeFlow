/// What the AI photo reader found (POST /scan), for the user to review.
sealed class ScanResult {
  const ScanResult();

  factory ScanResult.fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'receipt' => ScannedReceipt.fromJson(
          json['receipt'] as Map<String, dynamic>,
        ),
        'notes' => ScannedNotes.fromJson(json['notes'] as Map<String, dynamic>),
        'wishlist' => ScannedWishlist.fromJson(
          json['wishlist'] as Map<String, dynamic>,
        ),
        _ => throw const FormatException('Unknown scan result'),
      };
}

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String _str(Object? v) => v is String ? v : '';

/// One expense line (a receipt item, extra, or a note's line).
class ScannedLine {
  final String type; // 'expense' | 'income'
  final String name;
  final double amount;
  final String category; // '' when unknown
  final bool newCategory;
  final String date; // 'YYYY-MM-DD' or ''

  const ScannedLine({
    this.type = 'expense',
    required this.name,
    required this.amount,
    this.category = '',
    this.newCategory = false,
    this.date = '',
  });

  factory ScannedLine.fromJson(Map<String, dynamic> j) => ScannedLine(
    type: j['type'] == 'income' ? 'income' : 'expense',
    name: _str(j['name']),
    amount: _num(j['amount']),
    category: _str(j['category']),
    newCategory: j['new_category'] == true,
    date: _str(j['date']),
  );
}

class ScannedReceipt extends ScanResult {
  final String merchant;
  final String date;
  final List<ScannedLine> items;
  final List<ScannedLine> extras; // VAT, service charge, delivery…
  final double discount;
  final double total;

  const ScannedReceipt({
    required this.merchant,
    required this.date,
    required this.items,
    required this.extras,
    required this.discount,
    required this.total,
  });

  factory ScannedReceipt.fromJson(Map<String, dynamic> j) => ScannedReceipt(
    merchant: _str(j['merchant']),
    date: _str(j['date']),
    items: [
      for (final i in (j['items'] as List? ?? const []))
        ScannedLine.fromJson(i),
    ],
    extras: [
      for (final x in (j['extras'] as List? ?? const []))
        ScannedLine.fromJson(x),
    ],
    discount: _num(j['discount']),
    total: _num(j['total']),
  );
}

class ScannedNotes extends ScanResult {
  final String date; // the whole note's date, '' if none
  final List<ScannedLine> entries;

  const ScannedNotes({required this.date, required this.entries});

  factory ScannedNotes.fromJson(Map<String, dynamic> j) => ScannedNotes(
    date: _str(j['date']),
    entries: [
      for (final e in (j['entries'] as List? ?? const []))
        ScannedLine.fromJson(e),
    ],
  );
}

class ScannedWishItem {
  final String title;
  final String note;
  final double price;
  final String priority; // low | normal | high
  final String category;
  final String link;

  const ScannedWishItem({
    required this.title,
    this.note = '',
    this.price = 0,
    this.priority = 'normal',
    this.category = '',
    this.link = '',
  });

  factory ScannedWishItem.fromJson(Map<String, dynamic> j) => ScannedWishItem(
    title: _str(j['title']),
    note: _str(j['note']),
    price: _num(j['price']),
    priority: _str(j['priority']).isEmpty ? 'normal' : _str(j['priority']),
    category: _str(j['category']),
    link: _str(j['link']),
  );
}

class ScannedWishlist extends ScanResult {
  final List<ScannedWishItem> items;

  const ScannedWishlist({required this.items});

  factory ScannedWishlist.fromJson(Map<String, dynamic> j) => ScannedWishlist(
    items: [
      for (final i in (j['items'] as List? ?? const []))
        ScannedWishItem.fromJson(i),
    ],
  );
}

/// Shares a receipt's discount across its lines in proportion to their
/// amounts, in whole paisa, so the shares add up exactly to the discount.
List<double> discountShares(List<double> amounts, double discount) {
  final total = amounts.fold<double>(0, (a, b) => a + b);
  if (discount <= 0 || total <= 0) return List.filled(amounts.length, 0);
  final cents = (discount * 100).round();
  final shares = [for (final a in amounts) (cents * a / total).floor()];
  var left = cents - shares.fold<int>(0, (a, b) => a + b);
  // Hand leftover paisa to the largest lines first.
  final order = List.generate(amounts.length, (i) => i)
    ..sort((a, b) => amounts[b].compareTo(amounts[a]));
  for (var i = 0; left > 0; i = (i + 1) % order.length, left--) {
    shares[order[i]]++;
  }
  return [for (final s in shares) s / 100];
}

/// The image's real type from its first bytes (null when unsupported).
String? imageMimeType(List<int> b) {
  bool startsWith(List<int> sig, [int offset = 0]) =>
      b.length >= offset + sig.length &&
      [
        for (var i = 0; i < sig.length; i++) b[offset + i] == sig[i],
      ].every((x) => x);
  if (startsWith([0xFF, 0xD8])) return 'image/jpeg';
  if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (startsWith('WEBP'.codeUnits, 8)) return 'image/webp';
  if (startsWith('ftyp'.codeUnits, 4)) return 'image/heic';
  return null;
}
