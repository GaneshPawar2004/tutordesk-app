import '../core/utils/formatters.dart';
import '../shared/models/models.dart';

/// Parent message templates. Message *content* lives here, separate from any
/// future sending transport.
abstract final class MessageTemplates {
  static String attendance(
    AttendanceStatus status,
    String student,
    String tuition,
  ) {
    return switch (status) {
      AttendanceStatus.present =>
        'Dear Parent, your child $student was marked PRESENT at $tuition today.',
      AttendanceStatus.absent =>
        'Dear Parent, your child $student was marked ABSENT at $tuition today. '
            'Please contact us if this is incorrect.',
      AttendanceStatus.late =>
        'Dear Parent, your child $student arrived LATE at $tuition today.',
      AttendanceStatus.leave =>
        'Dear Parent, your child $student was marked ON LEAVE at $tuition today.',
    };
  }

  static String examResult({
    required String examName,
    required String student,
    required StudentResult result,
    required String tuition,
  }) {
    final lines = result.subjects
        .map((s) {
          if (s.isAbsent) return '${s.subject.name}: Absent';
          if (s.isMissing) return '${s.subject.name}: Not entered';
          return '${s.subject.name}: ${Fmt.marks(s.obtained)}/${Fmt.marks(s.maxMarks)}';
        })
        .join('\n');
    return 'Dear Parent, the $examName results for $student are available.\n\n'
        '$lines\n\n'
        'Total: ${Fmt.marks(result.obtained)}/${Fmt.marks(result.maxTotal)}\n'
        'Percentage: ${smartPercent(result.percent)}\n\n'
        'Regards,\n$tuition';
  }

  static String feeReminder(String student, int amount, String tuition) =>
      'Dear Parent, a fee balance of ${Fmt.currency(amount)} is due for '
      '$student at $tuition. Please clear it at your earliest convenience. '
      'Ignore if already paid.';

  static String announcement(String title, String body, String tuition) =>
      '$title\n\n$body\n\n– $tuition';

  /// 84% or 84.7% — whole numbers stay whole.
  static String smartPercent(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.toInt()}%';
    }
    return '${rounded.toStringAsFixed(1)}%';
  }
}
