/// "৳ 124,123" / "৳ 762.50": currency with thousands separators.
/// If [isVault] is true, conceals the monetary value for privacy (e.g. "৳ ••••••").
String formatMoney(num value, {int decimals = 0, bool isVault = false}) {
  if (isVault) return '৳ ••••••';
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = value < 0 ? '-' : '';
  return '$sign৳ $whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}
