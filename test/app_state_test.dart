import 'package:flutter_test/flutter_test.dart';
import 'package:tuition_app/data/mock_data.dart';
import 'package:tuition_app/shared/models/models.dart';

import 'test_utils.dart';

void main() {
  group('Seed data', () {
    test('matches the dashboard brief and stays internally consistent', () {
      final app = testState()..signInAsAdmin();
      expect(app.activeStudentCount, 128);
      expect(app.academic.runningClasses.length, 6);
      final today = app.todayAttendance();
      expect(today.classesMarked, 4);
      expect(today.classesTotal, 6);
      expect(app.staff.all.length, 5);
      expect(app.academic.years.length, greaterThanOrEqualTo(3));

      // Totals equal the sum of their parts.
      final rows = app.feeDirectory(yearId: kCurrentYearId);
      final totals = app.feeTotals(yearId: kCurrentYearId);
      expect(totals.agreed, rows.fold<int>(0, (s, r) => s + r.summary.agreed));
      expect(totals.paid, rows.fold<int>(0, (s, r) => s + r.summary.paid));
      expect(
        rows.map((r) => r.summary.status).toSet(),
        containsAll(PaymentStatus.values),
      );
    });

    test('Ganesh Pawar result is computed as 126/150 = 84%', () {
      final app = testState()..signInAsAdmin();
      final exam = app.exams.byId('exm-1');
      final r = app.resultFor(exam, 'STU-0001');
      expect(r.obtained, 126);
      expect(r.maxTotal, 150);
      expect(r.percent, closeTo(84, 0.001));
      expect(r.grade.label, 'A');
      final msg = app.resultMessage(exam, app.students.byId('STU-0001'));
      expect(msg, contains('Mathematics: 42/50'));
      expect(msg, contains('Total: 126/150'));
      expect(msg, contains('Percentage: 84%'));
    });

    test('fee schedule always sums to the annual fee', () {
      final s = FeePlan.buildSchedule(
        annualFee: 12001,
        count: 7,
        frequency: FeeFrequency.custom,
        firstDueDate: DateTime(2026, 6, 10),
      );
      expect(s.fold<int>(0, (a, i) => a + i.amount), 12001);
    });
  });

  group('Rules', () {
    test('attendance cannot be submitted twice for a session', () {
      final app = testState()..signInAsAdmin();
      final classId = 'cls-7';
      expect(app.todaySession(classId), isNull);
      final roster = app.rosterFor(classId);
      final first = app.saveAttendance(classId, {
        for (final s in roster) s.id: AttendanceStatus.present,
      });
      final second = app.saveAttendance(classId, {
        for (final s in roster) s.id: AttendanceStatus.absent,
      });
      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(second.session.id, first.session.id);
      expect(app.todaySession(classId)!.absentCount, 0);
    });

    test(
      'attendance notification batch is created once; retry resends failures only',
      () {
        final app = testState()..signInAsAdmin();
        final roster = app.rosterFor('cls-7');
        final session = app.saveAttendance('cls-7', {
          for (final s in roster) s.id: AttendanceStatus.present,
        }).session;
        final a = app.notifyAttendance(session, {...AttendanceStatus.values});
        final b = app.notifyAttendance(session, {...AttendanceStatus.values});
        expect(a.created, isTrue);
        expect(b.created, isFalse);
        expect(
          app.messaging.batches
              .where((x) => x.sourceKey == a.batch.sourceKey)
              .length,
          1,
        );

        final delivered = a.batch.recipients
            .where((r) => r.status.isSuccessful)
            .toList();
        final attemptsBefore = {for (final r in delivered) r.id: r.attempts};
        app.messaging.retryFailed(a.batch);
        expect(a.batch.failed, 0);
        for (final r in delivered) {
          expect(
            r.attempts,
            attemptsBefore[r.id],
            reason: 'successful recipients must not be resent',
          );
        }
      },
    );

    test('promotion adds an enrollment and never duplicates the student', () {
      final app = testState()..signInAsAdmin();
      final before = app.students.all.length;
      final from = app.academic.yearById(kCurrentYearId);
      final to = app.academic.yearById('ay-2027');
      final oldPlan = app.fees.planFor(
        app.students.enrollmentFor('STU-0001', kCurrentYearId)!.id,
      )!;
      final r = app.promote(
        from: from,
        to: to,
        toClass: app.academic.classById('cls-6'),
        studentIds: ['STU-0001'],
        annualFee: 13000,
      );
      expect(r.promoted.length, 1);
      expect(app.students.all.length, before);
      final history = app.historyOf('STU-0001');
      expect(history.map((e) => app.academic.classById(e.classId).name), [
        'Class 4',
        'Class 5',
        'Class 6',
      ]);
      // Previous year's fee untouched; new year has its own agreement.
      expect(app.fees.planFor(history[1].id), same(oldPlan));
      expect(oldPlan.annualFee, 12000);
      expect(app.fees.planFor(history[2].id)!.annualFee, 13000);
      // Promoting again is skipped, not duplicated.
      final again = app.promote(
        from: from,
        to: to,
        toClass: app.academic.classById('cls-6'),
        studentIds: ['STU-0001'],
      );
      expect(again.promoted, isEmpty);
      expect(again.skipped, ['STU-0001']);
    });

    test('payments are appended, never rewritten', () {
      final app = testState()..signInAsAdmin();
      final e = app.students.enrollmentFor('STU-0001', kCurrentYearId)!;
      final before = app.fees.paymentsFor(e.id).length;
      final balance = app.feeSummaryFor(e.id).outstanding;
      app.recordPayment(
        enrollment: e,
        amount: 500,
        date: app.today,
        method: PaymentMethod.cash,
      );
      app.recordPayment(
        enrollment: e,
        amount: 700,
        date: app.today,
        method: PaymentMethod.upi,
      );
      expect(app.fees.paymentsFor(e.id).length, before + 2);
      expect(app.feeSummaryFor(e.id).outstanding, balance - 1200);
    });

    test('staff permissions gate the UI flags; finance is never granted', () {
      final app = testState()..signInAsStaff('stf-1');
      expect(app.canSeeFinance, isFalse);
      expect(app.canSendMessages, isTrue);
      app.setStaffPermission(app.currentStaff!, StaffPermission.sendSms, false);
      expect(app.canSendMessages, isFalse);
      expect(app.visibleClasses.map((c) => c.id), ['cls-5', 'cls-6', 'cls-7']);
      expect(
        app.visibleBatches.any(
          (b) => b.category == MessageCategory.feeReminder,
        ),
        isFalse,
      );
    });

    test('absent marks are stored as absent, not as zero', () {
      final app = testState()..signInAsAdmin();
      final exam = app.exams.byId('exm-1');
      final absentEntry = exam.marks['sub-eng']!.values.firstWhere(
        (m) => m.absent,
      );
      expect(absentEntry.marks, isNull);
    });
  });
}
