import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'student_photo.dart';

/// Add / edit student dialog (screens 11-13). Returns true when saved.
Future<bool?> showStudentFormDialog(
  BuildContext context, {
  required SchoolClass schoolClass,
  Student? student,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) =>
        _StudentFormDialog(schoolClass: schoolClass, student: student),
  );
}

class _StudentFormDialog extends StatefulWidget {
  const _StudentFormDialog({required this.schoolClass, this.student});

  final SchoolClass schoolClass;
  final Student? student;

  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.student?.name);
  late final _father = TextEditingController(text: widget.student?.fatherName);
  late final _contact = TextEditingController(text: widget.student?.contact);
  late final _parent = TextEditingController(
    text: widget.student?.parentMobile,
  );
  late final _roll = TextEditingController(text: widget.student?.rollNo);
  late final _email = TextEditingController(text: widget.student?.email);
  late final _fees = TextEditingController(
    text: widget.student == null || widget.student!.totalFees == 0
        ? ''
        : _plain(widget.student!.totalFees),
  );
  late DateTime? _dob = widget.student?.dateOfBirth;
  late DateTime? _dueDate = widget.student?.feesDueDate;

  bool get _isEdit => widget.student != null;

  /// Photo picked in this form, uploaded on save.
  List<int>? _newPhoto;

  Future<void> _pickPhoto() async {
    final bytes = await pickStudentPhoto(context);
    if (bytes != null && mounted) setState(() => _newPhoto = bytes);
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_name, _father, _contact, _parent, _roll, _email, _fees]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optionalMobile(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    return isValidMobile(value) ? null : 'Enter a valid 10-digit number';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final body = appState.studentBody(
      name: _name.text.trim(),
      fatherName: _father.text.trim(),
      contact: _contact.text.trim(),
      parentMobile: _parent.text.trim(),
      rollNo: _roll.text.trim(),
      email: _email.text.trim(),
      dateOfBirth: _dob,
      totalFees: double.tryParse(_fees.text.trim()) ?? 0,
      feesDueDate: _dueDate,
    );
    final photo = _newPhoto;
    final ok = await runApi(context, () async {
      final Student s;
      if (_isEdit) {
        s = widget.student!;
        await appState.updateStudent(s, body);
      } else {
        s = await appState.addStudent(widget.schoolClass.id, body);
      }
      if (photo != null) await appState.uploadStudentPhoto(s, photo);
    });
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 6, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit Student' : 'Add Student',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 21),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                  children: [
                    Center(
                      child: _PhotoPicker(
                        onTap: _pickPhoto,
                        image: _newPhoto != null
                            ? CircleAvatar(
                                radius: 52,
                                backgroundImage: MemoryImage(
                                  Uint8List.fromList(_newPhoto!),
                                ),
                              )
                            : widget.student?.photoUpdatedAt != null
                            ? StudentPhoto(student: widget.student, radius: 52)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LabeledField(
                      label: 'Student name',
                      required: true,
                      hint: 'Enter student name',
                      controller: _name,
                    ),
                    LabeledField(
                      label: "Father's name",
                      hint: "Enter father's name",
                      controller: _father,
                    ),
                    LabeledField(
                      label: 'Contact',
                      hint: 'Enter contact number',
                      controller: _contact,
                      keyboardType: TextInputType.phone,
                      validator: _optionalMobile,
                    ),
                    LabeledField(
                      label: "Parent's mobile",
                      hint: "Parent's mobile number",
                      controller: _parent,
                      keyboardType: TextInputType.phone,
                      validator: _optionalMobile,
                    ),
                    LabeledField(
                      label: 'Roll number',
                      hint: 'Enter roll number',
                      controller: _roll,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final roll = v?.trim() ?? '';
                        if (roll.isEmpty) return null;
                        final taken = appState
                            .studentsOf(widget.schoolClass.id)
                            .any(
                              (s) => s.rollNo == roll && s != widget.student,
                            );
                        return taken
                            ? 'Roll number already used in this class'
                            : null;
                      },
                    ),
                    LabeledField(
                      label: 'Email',
                      hint: 'Enter email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return null;
                        return isValidEmail(value)
                            ? null
                            : 'Enter a valid email';
                      },
                    ),
                    DatePickerField(
                      label: 'Date of birth',
                      value: _dob,
                      lastDate: DateTime.now(),
                      helper: 'Used for birthday reminders.',
                      onChanged: (d) => setState(() => _dob = d),
                    ),
                    // Fee fields only with fee access (the server ignores them otherwise).
                    if (appState.canAccessFees) ...[
                      LabeledField(
                        label: 'Total fees',
                        hint: 'Enter total fees',
                        controller: _fees,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return null;
                          final n = double.tryParse(value);
                          return (n == null || n < 0)
                              ? 'Enter a valid amount'
                              : null;
                        },
                      ),
                      DatePickerField(
                        label: 'Fees due date',
                        value: _dueDate,
                        onChanged: (d) => setState(() => _dueDate = d),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(
                    _isEdit ? 'SAVE' : 'ADD',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.onTap, this.image});
  final VoidCallback onTap;

  /// Current/picked photo; a placeholder when null.
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 105,
        height: 105,
        child: Stack(
          children: [
            image ??
                const CircleAvatar(
                  radius: 52,
                  backgroundColor: Color(0xFFF2F2F2),
                  child: Icon(
                    Icons.person_outline,
                    size: 45,
                    color: AppColors.textMuted,
                  ),
                ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
