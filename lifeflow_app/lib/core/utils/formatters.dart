/// "৳ 124,123" / "৳ 762.50": currency with thousands separators.
String formatMoney(num value, {int decimals = 0}) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = value < 0 ? '-' : '';
  return '$sign৳ $whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}
