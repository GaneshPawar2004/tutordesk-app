import '../../shared/models/models.dart';
import 'mock_repository.dart';

/// Admin-only financial data. Payments are append-only.
class FeeRepository extends MockRepository {
  FeeRepository(
    super.onChanged, {
    required this._plans,
    required this._payments,
  });

  final List<FeePlan> _plans;
  final List<Payment> _payments;
  var _planCounter = 10000;
  var _paymentCounter = 10000;

  FeePlan? planFor(String enrollmentId) {
    for (final p in _plans) {
      if (p.enrollmentId == enrollmentId) return p;
    }
    return null;
  }

  /// Newest first.
  List<Payment> paymentsFor(String enrollmentId) =>
      _payments.where((p) => p.enrollmentId == enrollmentId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  int paidFor(String enrollmentId) => _payments
      .where((p) => p.enrollmentId == enrollmentId)
      .fold(0, (sum, p) => sum + p.amount);

  FeeSummary summaryFor(String enrollmentId, DateTime today) {
    final plan = planFor(enrollmentId);
    if (plan == null) return FeeSummary.empty;
    final paid = paidFor(enrollmentId);
    final dueSoFar = plan.schedule
        .where((i) => i.dueDate.isBefore(today))
        .fold<int>(0, (sum, i) => sum + i.amount);
    return FeeSummary(
      agreed: plan.annualFee,
      paid: paid,
      overdue: (dueSoFar - paid).clamp(0, plan.annualFee),
    );
  }

  /// Allocates payments to instalments in order to show per-instalment state.
  List<InstallmentProgress> progressFor(String enrollmentId, DateTime today) {
    final plan = planFor(enrollmentId);
    if (plan == null) return const [];
    var remaining = paidFor(enrollmentId);
    return [
      for (final inst in plan.schedule)
        () {
          final allocated = remaining.clamp(0, inst.amount);
          remaining -= allocated;
          final InstallmentState state;
          if (allocated >= inst.amount) {
            state = InstallmentState.paid;
          } else if (allocated > 0) {
            state = InstallmentState.partial;
          } else if (inst.dueDate.isBefore(today)) {
            state = InstallmentState.overdue;
          } else {
            state = InstallmentState.due;
          }
          return InstallmentProgress(
            installment: inst,
            paid: allocated,
            state: state,
          );
        }(),
    ];
  }

  List<Payment> recent({int limit = 10, Set<String>? enrollmentIds}) {
    final list =
        _payments
            .where(
              (p) =>
                  enrollmentIds == null ||
                  enrollmentIds.contains(p.enrollmentId),
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    return list.take(limit).toList();
  }

  List<Payment> paymentsBetween(
    DateTime from,
    DateTime to,
    Set<String> enrollmentIds,
  ) => _payments
      .where(
        (p) =>
            enrollmentIds.contains(p.enrollmentId) &&
            !p.date.isBefore(from) &&
            !p.date.isAfter(to),
      )
      .toList();

  FeePlan addPlan({
    required String enrollmentId,
    required int annualFee,
    required int installmentCount,
    required FeeFrequency frequency,
    required DateTime firstDueDate,
    String? note,
  }) {
    assert(planFor(enrollmentId) == null, 'One fee plan per enrollment');
    final plan = FeePlan(
      id: 'fee-${++_planCounter}',
      enrollmentId: enrollmentId,
      annualFee: annualFee,
      installmentCount: installmentCount,
      frequency: frequency,
      firstDueDate: firstDueDate,
      note: note,
    );
    _plans.add(plan);
    changed();
    return plan;
  }

  Payment record({
    required String enrollmentId,
    required int amount,
    required DateTime date,
    required PaymentMethod method,
    required String recordedBy,
    String? reference,
    String? note,
  }) {
    final payment = Payment(
      id: 'pay-${++_paymentCounter}',
      enrollmentId: enrollmentId,
      amount: amount,
      date: date,
      method: method,
      recordedBy: recordedBy,
      reference: reference,
      note: note,
    );
    _payments.add(payment);
    changed();
    return payment;
  }
}
