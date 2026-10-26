import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuition_app/app.dart';
import 'package:tuition_app/data/app_state.dart';
import 'package:tuition_app/data/mock_data.dart';
import 'package:tuition_app/features/academic_years/academic_years_screen.dart';
import 'package:tuition_app/features/academic_years/promotion_screen.dart';
import 'package:tuition_app/features/attendance/attendance_summary_screen.dart';
import 'package:tuition_app/features/attendance/class_attendance_screen.dart';
import 'package:tuition_app/features/attendance/notify_parents_screen.dart';
import 'package:tuition_app/features/classes/classes_screen.dart';
import 'package:tuition_app/features/exams/create_exam_screen.dart';
import 'package:tuition_app/features/exams/exam_detail_screen.dart';
import 'package:tuition_app/features/exams/exam_results_screen.dart';
import 'package:tuition_app/features/exams/exams_screen.dart';
import 'package:tuition_app/features/exams/marks_entry_screen.dart';
import 'package:tuition_app/features/exams/send_results_screen.dart';
import 'package:tuition_app/features/exams/student_result_screen.dart';
import 'package:tuition_app/features/fees/fees_dashboard_screen.dart';
import 'package:tuition_app/features/fees/record_payment_screen.dart';
import 'package:tuition_app/features/fees/student_fee_detail_screen.dart';
import 'package:tuition_app/features/fees/student_fees_screen.dart';
import 'package:tuition_app/features/messaging/announcement_screen.dart';
import 'package:tuition_app/features/messaging/batch_detail_screen.dart';
import 'package:tuition_app/features/messaging/messages_screen.dart';
import 'package:tuition_app/features/messaging/sms_settings_screen.dart';
import 'package:tuition_app/features/notifications/notifications_screen.dart';
import 'package:tuition_app/features/profile/profile_screen.dart';
import 'package:tuition_app/features/profile/settings_screens.dart';
import 'package:tuition_app/features/reports/reports_screen.dart';
import 'package:tuition_app/features/staff/staff_detail_screen.dart';
import 'package:tuition_app/features/staff/staff_form_screen.dart';
import 'package:tuition_app/features/staff/staff_screen.dart';
import 'package:tuition_app/features/students/student_form_screen.dart';
import 'package:tuition_app/features/students/student_profile_screen.dart';

import 'test_utils.dart';

Map<String, Widget Function(AppState)> _screens() => {
  'promotion': (_) => const PromotionScreen(),
  'academic years': (_) => const AcademicYearsScreen(),
  'classes': (_) => const ClassesScreen(),
  'class detail': (_) => const ClassDetailScreen(classId: 'cls-5'),
  'class form': (_) => const ClassFormScreen(),
  'attendance marking': (_) => const ClassAttendanceScreen(classId: 'cls-7'),
  'attendance summary': (a) =>
      AttendanceSummaryScreen(sessionId: a.todaySession('cls-5')!.id),
  'notify parents': (a) =>
      NotifyParentsScreen(sessionId: a.todaySession('cls-5')!.id),
  'exams': (_) => const ExamsScreen(),
  'create exam': (_) => const CreateExamScreen(initialClassId: 'cls-5'),
  'exam detail': (_) => const ExamDetailScreen(examId: 'exm-1'),
  'marks entry': (_) => const MarksEntryScreen(examId: 'exm-2'),
  'exam results': (_) => const ExamResultsScreen(examId: 'exm-1'),
  'student result': (_) =>
      const StudentResultScreen(examId: 'exm-1', studentId: 'STU-0001'),
  'send results': (_) => const SendResultsScreen(examId: 'exm-7'),
  'fees dashboard': (_) => const FeesDashboardScreen(),
  'student fees': (_) => const StudentFeesScreen(),
  'fee detail': (a) => StudentFeeDetailScreen(
    enrollmentId: a.students.enrollmentFor('STU-0001', kCurrentYearId)!.id,
  ),
  'record payment': (a) => RecordPaymentScreen(
    enrollmentId: a.students.enrollmentFor('STU-0001', kCurrentYearId)!.id,
  ),
  'messages': (_) => const MessagesScreen(),
  'batch detail': (_) => const BatchDetailScreen(batchId: 'bat-4'),
  'announcement': (_) => const AnnouncementScreen(),
  'sms settings': (_) => const SmsSettingsScreen(),
  'notifications': (_) => const NotificationsScreen(),
  'profile': (_) => const ProfileScreen(),
  'tuition info': (_) => const TuitionInfoScreen(),
  'reports': (_) => const ReportsScreen(),
  'staff': (_) => const StaffScreen(),
  'staff detail': (_) => const StaffDetailScreen(staffId: 'stf-5'),
  'staff form': (_) => const StaffFormScreen(),
  'admission form': (_) => const StudentFormScreen(),
  'student profile': (_) => const StudentProfileScreen(studentId: 'STU-0001'),
};

void main() {
  testWidgets('role selection → admin shell; all four tabs render', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final state = testState();
    await tester.pumpWidget(TuitionApp(state: state));
    expect(find.textContaining('in one place'), findsOneWidget);
    await tester.ensureVisible(find.text('ADMIN PREVIEW'));
    await tester.tap(find.text('ADMIN PREVIEW'));
    await tester.pumpAndSettle();
    expect(find.text('Bright Future Classes'), findsWidgets);
    final home = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Pending fees'),
      200,
      scrollable: home,
    );
    await tester.scrollUntilVisible(
      find.text('Record\nPayment'),
      200,
      scrollable: home,
    );
    for (final tab in ['Students', 'Attendance', 'More', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Fees & payments'), findsNothing); // on Home again
  });

  testWidgets('staff view hides every financial element', (tester) async {
    await setPhoneSize(tester);
    final state = testState()..signInAsStaff('stf-1');
    await tester.pumpWidget(TuitionApp(state: state));
    await tester.pumpAndSettle();
    // Scroll the whole dashboard checking for any financial content.
    final home = find.byType(Scrollable).first;
    for (var i = 0; i < 8; i++) {
      expect(find.text('Pending fees'), findsNothing);
      expect(find.text('Record\nPayment'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      await tester.drag(home, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('Fees & payments'), findsNothing);
    expect(find.text('Staff'), findsNothing);
    // Direct navigation is also blocked.
    await tester.pumpWidget(host(state, const FeesDashboardScreen()));
    expect(find.text('Admin only'), findsOneWidget);
  });

  group('every screen renders without overflow on a 360×640 phone', () {
    for (final entry in _screens().entries) {
      testWidgets('admin · ${entry.key}', (tester) async {
        await setPhoneSize(tester);
        final state = testState()..signInAsAdmin();
        await tester.pumpWidget(host(state, entry.value(state)));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('staff screens render without overflow', () {
    const names = [
      'student profile',
      'attendance marking',
      'attendance summary',
      'notify parents',
      'exams',
      'exam detail',
      'marks entry',
      'student result',
      'messages',
      'batch detail',
      'reports',
      'profile',
      'notifications',
    ];
    for (final name in names) {
      testWidgets('staff · $name', (tester) async {
        await setPhoneSize(tester);
        final state = testState()..signInAsStaff('stf-1');
        final screen = name == 'marks entry' || name == 'batch detail'
            ? (name == 'marks entry'
                  ? const MarksEntryScreen(examId: 'exm-1')
                  : const BatchDetailScreen(batchId: 'bat-1'))
            : _screens()[name]!(state);
        await tester.pumpWidget(host(state, screen));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('₹'), findsNothing);
      });
    }
  });

  group('large text (1.3×)', () {
    for (final name in [
      'admission form',
      'student profile',
      'fees dashboard',
      'marks entry',
      'attendance marking',
    ]) {
      testWidgets(name, (tester) async {
        await setPhoneSize(tester, size: const Size(392, 800));
        final state = testState()..signInAsAdmin();
        await tester.pumpWidget(
          host(state, _screens()[name]!(state), textScale: 1.3),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('marks entry rejects marks above the maximum', (tester) async {
    await setPhoneSize(tester, size: const Size(392, 800));
    final state = testState()..signInAsAdmin();
    await tester.pumpWidget(
      host(state, const MarksEntryScreen(examId: 'exm-2')),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, '30');
    await tester.pump();
    expect(find.text('Max 25'), findsOneWidget);
  });
}
