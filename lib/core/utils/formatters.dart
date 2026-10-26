/// Formatting helpers with Indian conventions (₹, lakh grouping, +91).
/// Written by hand to avoid pulling in `intl` for the static phase.
abstract final class Fmt {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// ₹1,25,000
  static String currency(num amount) {
    final negative = amount < 0;
    final digits = amount.abs().round().toString();
    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      grouped = '${parts.join(',')},$last3';
    }
    return '${negative ? '-' : ''}₹$grouped';
  }

  /// ₹4.2L, ₹86.5K — for dense summary tiles.
  static String compactCurrency(num amount) {
    final value = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (value >= 10000000) return '$sign₹${_trim(value / 10000000)}Cr';
    if (value >= 100000) return '$sign₹${_trim(value / 100000)}L';
    if (value >= 1000) return '$sign₹${_trim(value / 1000)}K';
    return currency(amount);
  }

  static String _trim(num v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String date(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String weekdayDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  static String longDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_monthsLong[d.month - 1]} ${d.year}';

  static String monthYear(DateTime d) =>
      '${_monthsLong[d.month - 1]} ${d.year}';

  static String month(int month) => _months[month - 1];

  static String weekdayLetter(int weekday) => _weekdays[weekday - 1][0];

  static String time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static String dateTime(DateTime d) => '${shortDate(d)}, ${time(d)}';

  static String relative(DateTime d, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(d);
    if (diff.isNegative) return dateTime(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (isSameDay(d, ref)) return time(d);
    if (isSameDay(d, ref.subtract(const Duration(days: 1)))) {
      return 'Yesterday, ${time(d)}';
    }
    return dateTime(d);
  }

  /// "+91 98220 41567"
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final local = digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;
    if (local.length != 10) return raw;
    return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
  }

  /// "••• 4567" — used where the full number is not needed.
  static String phoneSuffix(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return raw;
    return '••• ${digits.substring(digits.length - 4)}';
  }

  static String percent(double value, {int decimals = 0}) {
    final s = value.toStringAsFixed(decimals);
    return '$s%';
  }

  /// 42 or 42.5 — never "42.0".
  static String marks(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String plural(int count, String singular, [String? pluralForm]) =>
      '$count ${count == 1 ? singular : (pluralForm ?? '${singular}s')}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
