enum PaymentMethod {
  cash('Cash'),
  upi('UPI'),
  bankTransfer('Bank transfer'),
  cheque('Cheque'),
  card('Card');

  const PaymentMethod(this.label);
  final String label;
}

enum FeeFrequency {
  monthly('Monthly', 1),
  quarterly('Quarterly', 3),
  halfYearly('Half-yearly', 6),
  custom('Custom schedule', 0);

  const FeeFrequency(this.label, this.monthStep);
  final String label;

  /// Months between instalments. 0 means "spread evenly over the year".
  final int monthStep;
}

enum PaymentStatus {
  paid('Paid'),
  partial('Partial'),
  unpaid('Unpaid');

  const PaymentStatus(this.label);
  final String label;
}

/// The fee agreed for a single enrollment (one student, one academic year).
class FeePlan {
  FeePlan({
    required this.id,
    required this.enrollmentId,
    required this.annualFee,
    required this.installmentCount,
    required this.frequency,
    required this.firstDueDate,
    this.note,
  });

  final String id;
  final String enrollmentId;
  final int annualFee;
  final int installmentCount;
  final FeeFrequency frequency;
  final DateTime firstDueDate;
  final String? note;

  /// Splits the annual fee into instalments. Any remainder goes to the last
  /// instalment so the schedule always sums exactly to [annualFee].
  List<Installment> get schedule => buildSchedule(
    annualFee: annualFee,
    count: installmentCount,
    frequency: frequency,
    firstDueDate: firstDueDate,
  );

  static List<Installment> buildSchedule({
    required int annualFee,
    required int count,
    required FeeFrequency frequency,
    required DateTime firstDueDate,
  }) {
    if (count <= 0 || annualFee <= 0) return const [];
    final base = annualFee ~/ count;
    final remainder = annualFee - base * count;
    final step = frequency.monthStep > 0
        ? frequency.monthStep
        : (10 ~/ count).clamp(1, 12);
    return List.generate(count, (i) {
      final due = DateTime(
        firstDueDate.year,
        firstDueDate.month + i * step,
        firstDueDate.day.clamp(1, 28),
      );
      return Installment(
        number: i + 1,
        dueDate: due,
        amount: base + (i == count - 1 ? remainder : 0),
      );
    });
  }
}

class Installment {
  const Installment({
    required this.number,
    required this.dueDate,
    required this.amount,
  });

  final int number;
  final DateTime dueDate;
  final int amount;
}

/// Payments are append-only: balances are always derived from the full list,
/// never by editing or deleting earlier payments.
class Payment {
  const Payment({
    required this.id,
    required this.enrollmentId,
    required this.amount,
    required this.date,
    required this.method,
    required this.recordedBy,
    this.reference,
    this.note,
  });

  final String id;
  final String enrollmentId;
  final int amount;
  final DateTime date;
  final PaymentMethod method;
  final String recordedBy;
  final String? reference;
  final String? note;
}

enum InstallmentState { paid, partial, due, overdue }

class InstallmentProgress {
  const InstallmentProgress({
    required this.installment,
    required this.paid,
    required this.state,
  });

  final Installment installment;
  final int paid;
  final InstallmentState state;

  int get remaining => installment.amount - paid;
}

class FeeSummary {
  const FeeSummary({
    required this.agreed,
    required this.paid,
    required this.overdue,
  });

  static const empty = FeeSummary(agreed: 0, paid: 0, overdue: 0);

  final int agreed;
  final int paid;
  final int overdue;

  int get outstanding => (agreed - paid).clamp(0, agreed);

  double get progress => agreed == 0 ? 0 : (paid / agreed).clamp(0.0, 1.0);

  PaymentStatus get status {
    if (agreed > 0 && paid >= agreed) return PaymentStatus.paid;
    if (paid > 0) return PaymentStatus.partial;
    return PaymentStatus.unpaid;
  }

  FeeSummary operator +(FeeSummary other) => FeeSummary(
    agreed: agreed + other.agreed,
    paid: paid + other.paid,
    overdue: overdue + other.overdue,
  );
}
