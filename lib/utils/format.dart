String formatDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';
}

String formatMoney(num amount) {
  final whole = amount == amount.roundToDouble();
  return '₹${whole ? amount.toInt() : amount.toStringAsFixed(2)}';
}

bool isValidEmail(String v) =>
    RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v.trim());

bool isValidMobile(String v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim());

String maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2 || parts[0].length <= 2) return email;
  final name = parts[0];
  return '${name.substring(0, 2)}${'*' * (name.length - 2)}@${parts[1]}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "2026-08" → "Aug 2026".
String formatMonth(String? yyyyMm) {
  final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(yyyyMm ?? '');
  if (m == null) return '';
  return '${_months[int.parse(m[2]!) - 1]} ${m[1]}';
}

/// Fees start: "YYYY-MM-DD", or an older month-only "YYYY-MM" (the 1st).
DateTime? parseFeeStart(String? v) {
  final m = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$').firstMatch(v ?? '');
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3] ?? '1'));
}

/// "2026-09-15" -> "15-09-2026"; month-only values -> "Sep 2026".
String formatFeeStart(String? v) {
  final m = RegExp(r'^\d{4}-\d{2}$').hasMatch(v ?? '');
  return m ? formatMonth(v) : formatDate(parseFeeStart(v));
}
