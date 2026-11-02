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
