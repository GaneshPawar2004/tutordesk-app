import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/export.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';
import '../classes/class_detail_screen.dart';
import '../fees/collect_fee_dialog.dart';
import 'student_form_dialog.dart';
import 'student_photo.dart';
import 'student_profile_screen.dart';
import 'students_view.dart';

/// Grid of quick actions shown when tapping a student (screen 15).
Future<void> showStudentActionsDialog(
  BuildContext context, {
  required Student student,
  required SchoolClass schoolClass,
  required ValueChanged<ClassTab> onOpenTab,
}) {
  return showDialog(
    context: context,
    builder: (ctx) {
      final s = student;

      // Close the dialog first, then run the action on the page context.
      void run(void Function() action) {
        Navigator.of(ctx).pop();
        action();
      }

      // Runs [action] with the number, or explains that none is saved.
      void withNumber(String number, void Function(String) action) {
        if (number.isEmpty) {
          showError(context, 'No mobile number saved for ${s.name}.');
        } else {
          action(number);
        }
      }

      final actions = <_Action>[
        _Action(
          Icons.call_outlined,
          'Call',
          const Color(0xFF1565C0),
          const Color(0xFFE3F2FD),
          () => run(
            () => withNumber(
              s.contact.isNotEmpty ? s.contact : s.parentMobile,
              (n) => openDialer(context, n),
            ),
          ),
        ),
        _Action(
          Icons.sms_outlined,
          'SMS',
          const Color(0xFF2E7D32),
          const Color(0xFFE6F4EA),
          () => run(
            () => withNumber(
              parentNumber(s),
              (n) => openSms(context, [n], 'Dear Parent, '),
            ),
          ),
        ),
        _Action(
          Icons.payments_outlined,
          'Fees',
          const Color(0xFFC62828),
          const Color(0xFFFCE4EC),
          () => run(() => showCollectFeeDialog(context, s)),
        ),
        _Action(
          Icons.event_available_outlined,
          'Attendance',
          const Color(0xFF3949AB),
          const Color(0xFFE8EAF6),
          () => run(() => onOpenTab(ClassTab.attendance)),
        ),
        _Action(
          Icons.edit_outlined,
          'Edit',
          const Color(0xFF8E24AA),
          const Color(0xFFF3E5F5),
          () => run(() async {
            final saved = await showStudentFormDialog(
              context,
              schoolClass: schoolClass,
              student: s,
            );
            if (saved == true && context.mounted) {
              showSuccess(context, 'Student updated successfully!');
            }
          }),
        ),
        _Action(
          Icons.photo_camera_outlined,
          'View Photo',
          const Color(0xFF00796B),
          const Color(0xFFE0F2F1),
          () => run(() => showStudentPhotoDialog(context, s)),
        ),
        _Action(
          Icons.trending_up,
          'Report',
          const Color(0xFF3949AB),
          const Color(0xFFE8EAF6),
          () => run(() => _openProfile(context, s, schoolClass)),
        ),
        _Action(
          Icons.download_outlined,
          'Export',
          const Color(0xFFE65100),
          const Color(0xFFFFF3E0),
          () => run(() => exportStudent(context, s)),
        ),
        _Action(
          s.disabled ? Icons.check_circle_outline : Icons.block,
          s.disabled ? 'Enable' : 'Disable',
          const Color(0xFFF57C00),
          const Color(0xFFFFF8E1),
          () => run(() async {
            if (!s.disabled) {
              final ok = await confirmDialog(
                context,
                title: 'Disable ${s.name}?',
                message:
                    'Disabled students are hidden from attendance and tests.',
                confirmLabel: 'DISABLE',
                confirmColor: const Color(0xFFF57C00),
              );
              if (!ok) return;
            }
            if (!context.mounted) return;
            final done = await runApi(
              context,
              () => appState.toggleStudentDisabled(s),
            );
            if (done && context.mounted) {
              showSuccess(
                context,
                s.disabled ? 'Student disabled' : 'Student enabled',
              );
            }
          }),
        ),
        // Only the admin can delete students.
        if (appState.isOwner)
          _Action(
            Icons.person_remove_outlined,
            'Delete',
            const Color(0xFFC62828),
            const Color(0xFFFFEBEE),
            () => run(() async {
              final ok = await confirmDialog(
                context,
                title: 'Delete ${s.name}?',
                message:
                    'This removes the student with all attendance, marks and fee records.',
              );
              if (ok && context.mounted) {
                if (await runApi(context, () => appState.deleteStudent(s)) &&
                    context.mounted) {
                  showSuccess(context, 'Student deleted');
                }
              }
            }),
          ),
      ];

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StudentAvatar(radius: 34, disabled: s.disabled, student: s),
                const SizedBox(height: 10),
                Text(
                  s.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  schoolClass.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 15),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: actions.map((a) => _ActionTile(a)).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () =>
                        run(() => _openProfile(context, s, schoolClass)),
                    child: const Text(
                      'VIEW FULL PROFILE',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _openProfile(BuildContext context, Student s, SchoolClass c) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StudentProfileScreen(student: s, schoolClass: c),
    ),
  );
}

class _Action {
  const _Action(this.icon, this.label, this.color, this.background, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(this.action);
  final _Action action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: action.color, size: 24),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                action.label,
                style: TextStyle(color: action.color, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
