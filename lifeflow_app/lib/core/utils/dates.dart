/// "2026-10-14": how a day is stored and compared.
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Midnight at the start of [d]'s day.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
