import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'student_profile_screen.dart';

/// Admission form (new student) and student edit form.
///
/// The fee section is built only for admins creating a new admission; staff
/// never see or reach these controls.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.student});

  final Student? student;

  bool get isEdit => student != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _parent = TextEditingController();
  final _phone = TextEditingController();
  final _altPhone = TextEditingController();
  final _address = TextEditingController();
  final _fee = TextEditingController();
  final _installments = TextEditingController(text: '6');
  final _initial = TextEditingController();
  final _note = TextEditingController();

  DateTime? _dob;
  Gender? _gender;
  late String _studentId;
  String? _yearId;
  String? _classId;
  DateTime _enrolledOn = DateTime.now();
  var _active = true;

  var _withFee = true;
  var _frequency = FeeFrequency.monthly;
  late DateTime _firstDue;
  DateTime _paymentDate = DateTime.now();
  var _method = PaymentMethod.upi;
  var _dirty = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDue = DateTime(now.year, now.month + 1, 10);
    final s = widget.student;
    if (s != null) {
      _studentId = s.id;
      _first.text = s.firstName;
      _last.text = s.lastName;
      _parent.text = s.parentName;
      _phone.text = s.parentPhone;
      _altPhone.text = s.altPhone ?? '';
      _address.text = s.address ?? '';
      _dob = s.dateOfBirth;
      _gender = s.gender;
      _active = s.isActive;
    }
    for (final c in [
      _first,
      _last,
      _parent,
      _phone,
      _altPhone,
      _address,
      _fee,
      _initial,
      _note,
    ]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.isEdit && _yearId == null) {
      final app = context.appRead;
      _studentId = app.students.nextStudentId();
      _yearId = app.currentYear.id;
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _parent,
      _phone,
      _altPhone,
      _address,
      _fee,
      _installments,
      _initial,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _feeValue => AmountField.parse(_fee.text);
  int get _initialValue => AmountField.parse(_initial.text);
  int get _installmentCount => int.tryParse(_installments.text) ?? 0;

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return ConfirmationDialog.show(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes on this form. They will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
  }

  Future<void> _close() async {
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
  }

  String? _required(String? v, String what) =>
      (v ?? '').trim().isEmpty ? 'Enter $what' : null;

  Future<void> _save() async {
    final app = context.appRead;
    final valid = _formKey.currentState!.validate();
    if (!valid) {
      AppToast.show(
        context,
        'Please fix the highlighted fields.',
        type: ToastType.error,
      );
      return;
    }
    setState(() => _saving = true);
    // A short pause so the saving state is visible; nothing is written to disk.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    if (widget.isEdit) {
      final s = widget.student!
        ..firstName = _first.text.trim()
        ..lastName = _last.text.trim()
        ..dateOfBirth = _dob!
        ..gender = _gender
        ..parentName = _parent.text.trim()
        ..parentPhone = _phone.text.trim()
        ..altPhone = opt(_altPhone)
        ..address = opt(_address);
      if (app.isAdmin) s.isActive = _active;
      app.students.update(s);
      Navigator.of(context).pop();
      AppToast.show(context, 'Student details updated');
      return;
    }

    final student = app.addStudent(
      AdmissionDraft(
        studentId: _studentId,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        dateOfBirth: _dob!,
        gender: _gender,
        parentName: _parent.text.trim(),
        parentPhone: _phone.text.trim(),
        altPhone: opt(_altPhone),
        address: opt(_address),
        yearId: _yearId!,
        classId: _classId!,
        enrolledOn: _enrolledOn,
        active: _active,
        fee: app.isAdmin && _withFee
            ? FeeDraft(
                annualFee: _feeValue,
                installments: _installmentCount,
                frequency: _frequency,
                firstDueDate: _firstDue,
                initialAmount: _initialValue,
                paymentDate: _paymentDate,
                method: _method,
                note: opt(_note),
              )
            : null,
      ),
    );
    setState(() {
      _saving = false;
      _dirty = false;
    });
    await _showSuccess(student);
  }

  Future<void> _showSuccess(Student student) async {
    final app = context.appRead;
    final viewProfile = await showAppSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconWell(
              icon: Icons.check_rounded,
              color: AppColors.success,
              size: 64,
            ),
            const SizedBox(height: Gap.md),
            Text('Student added', style: AppTextStyles.title),
            const SizedBox(height: 6),
            Text(
              '${student.fullName} (${student.id}) is enrolled in ${app.classNameOf(student.id, _yearId)} '
              'for ${app.academic.yearById(_yearId!).label}.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 6),
            Text(
              'Saved in this session only — demo data resets when the app restarts.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(height: Gap.lg),
            PrimaryButton(
              label: 'View profile',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (viewProfile ?? false) {
      replacePage(context, StudentProfileScreen(studentId: student.id));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final isEdit = widget.isEdit;
    final showFees = app.isAdmin && !isEdit;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AppScaffold(
        title: isEdit ? 'Edit student' : 'New admission',
        subtitle: isEdit ? widget.student!.fullName : app.tuition.name,
        onBack: _close,
        bottomBar: Row(
          children: [
            Expanded(
              child: SecondaryButton(label: 'Cancel', onPressed: _close),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: isEdit ? 'Save changes' : 'Save student',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.sm,
              Gap.page,
              Gap.xl,
            ),
            children: [
              const _FormSection(letter: 'A', title: 'Student information'),
              _PhotoPicker(
                name: '${_first.text} ${_last.text}',
                studentId: _studentId,
              ),
              const SizedBox(height: Gap.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'First name',
                      controller: _first,
                      hint: 'Ganesh',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => _required(v, 'first name'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      label: 'Last name',
                      controller: _last,
                      hint: 'Pawar',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => _required(v, 'last name'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              DatePickerField(
                label: 'Date of birth',
                value: _dob,
                firstDate: DateTime(1995),
                lastDate: DateTime.now(),
                validator: (v) => v == null ? 'Select date of birth' : null,
                onChanged: (d) => setState(() {
                  _dob = d;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: Gap.md),
              const FieldLabel('Gender', optional: true),
              SegmentedChoice<Gender>(
                options: [
                  for (final g in Gender.values) SelectOption(g, g.label),
                ],
                value: _gender,
                onChanged: (g) => setState(() {
                  _gender = _gender == g ? null : g;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: Gap.md),
              const FieldLabel('Student ID'),
              _ReadOnlyValue(
                value: _studentId,
                hint: isEdit
                    ? 'Permanent ID · cannot be changed'
                    : 'Generated automatically',
              ),
              const SizedBox(height: Gap.md),
              CustomTextField(
                label: 'Parent / guardian name',
                controller: _parent,
                hint: 'Sunil Pawar',
                textCapitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'parent or guardian name'),
              ),
              const SizedBox(height: Gap.md),
              PhoneField(label: 'Parent mobile number', controller: _phone),
              const SizedBox(height: Gap.md),
              PhoneField(
                label: 'Alternate mobile number',
                controller: _altPhone,
                optional: true,
              ),
              const SizedBox(height: Gap.md),
              CustomTextField(
                label: 'Address',
                controller: _address,
                optional: true,
                maxLines: 3,
                hint: 'Flat, building, area, city',
                textCapitalization: TextCapitalization.sentences,
              ),
              if (!isEdit) ...[
                const _FormSection(letter: 'B', title: 'Enrollment'),
                SelectField<String>(
                  label: 'Academic year',
                  value: _yearId,
                  options: [
                    for (final y in app.academic.years.where(
                      (y) => y.status != YearStatus.closed,
                    ))
                      SelectOption(y.id, y.label, subtitle: y.status.label),
                  ],
                  onChanged: (v) => setState(() => _yearId = v),
                  validator: (v) =>
                      v == null ? 'Select an academic year' : null,
                ),
                const SizedBox(height: Gap.md),
                SelectField<String>(
                  label: 'Class',
                  value: _classId,
                  hint: 'Select class',
                  options: [
                    for (final c in app.academic.runningClasses)
                      SelectOption(
                        c.id,
                        c.name,
                        subtitle:
                            '${c.sessionLabel} · ${Fmt.plural(app.enrolledCount(c.id, _yearId), 'student')}',
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _classId = v;
                    _dirty = true;
                  }),
                  validator: (v) => v == null ? 'Select a class' : null,
                ),
                const SizedBox(height: Gap.md),
                DatePickerField(
                  label: 'Enrollment date',
                  value: _enrolledOn,
                  onChanged: (d) => setState(() => _enrolledOn = d),
                ),
                const SizedBox(height: Gap.md),
              ] else
                const SizedBox(height: Gap.md),
              if (!isEdit || app.isAdmin) ...[
                FieldLabel(isEdit ? 'Student status' : 'Enrollment status'),
                SegmentedChoice<bool>(
                  options: const [
                    SelectOption(true, 'Active'),
                    SelectOption(false, 'Inactive'),
                  ],
                  value: _active,
                  onChanged: (v) => setState(() {
                    _active = v;
                    _dirty = true;
                  }),
                ),
              ],
              if (isEdit) ...[
                const SizedBox(height: Gap.md),
                const DemoNotice(
                  icon: Icons.swap_vert_rounded,
                  text:
                      'Class changes for a new academic year are made through promotion, '
                      'which keeps this student\'s permanent record and history.',
                ),
              ],
              if (showFees) ..._feeSection(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feeSection() {
    final fee = _feeValue;
    final initial = _initialValue;
    final count = _installmentCount;
    final schedule = FeePlan.buildSchedule(
      annualFee: fee,
      count: count.clamp(0, 36),
      frequency: _frequency,
      firstDueDate: _firstDue,
    );
    return [
      _FormSection(
        letter: 'C',
        title: 'Fees',
        trailing: const StatusChip(
          label: 'Admin only',
          color: AppColors.warning,
          dense: true,
        ),
      ),
      SwitchListTile(
        value: _withFee,
        onChanged: (v) => setState(() => _withFee = v),
        contentPadding: EdgeInsets.zero,
        title: Text('Add fee agreement now', style: AppTextStyles.titleSmall),
        subtitle: Text(
          'You can also set it later from Fees.',
          style: AppTextStyles.caption,
        ),
      ),
      if (_withFee) ...[
        const SizedBox(height: Gap.sm),
        AmountField(
          label: 'Agreed annual fee',
          controller: _fee,
          onChanged: (_) => setState(() {}),
          validator: (v) => AmountField.parse(v ?? '') <= 0
              ? 'Enter the agreed annual fee'
              : null,
        ),
        const SizedBox(height: Gap.md),
        const FieldLabel('Number of instalments'),
        _InstallmentStepper(
          controller: _installments,
          onChanged: () => setState(() => _dirty = true),
        ),
        const SizedBox(height: Gap.md),
        const FieldLabel('Payment frequency'),
        SegmentedChoice<FeeFrequency>(
          options: [
            for (final f in FeeFrequency.values) SelectOption(f, f.label),
          ],
          value: _frequency,
          onChanged: (f) => setState(() => _frequency = f),
        ),
        const SizedBox(height: Gap.md),
        DatePickerField(
          label: 'First instalment due',
          value: _firstDue,
          onChanged: (d) => setState(() => _firstDue = d),
        ),
        const SizedBox(height: Gap.md),
        AmountField(
          label: 'Initial amount received',
          controller: _initial,
          optional: true,
          helper: 'Any amount — it does not have to match one instalment.',
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final value = AmountField.parse(v ?? '');
            if (value > _feeValue && _feeValue > 0) {
              return 'Cannot exceed the annual fee';
            }
            return null;
          },
        ),
        if (initial > 0) ...[
          const SizedBox(height: Gap.md),
          DatePickerField(
            label: 'Payment date',
            value: _paymentDate,
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _paymentDate = d),
          ),
          const SizedBox(height: Gap.md),
          const FieldLabel('Payment method'),
          SegmentedChoice<PaymentMethod>(
            options: [
              for (final m in PaymentMethod.values) SelectOption(m, m.label),
            ],
            value: _method,
            onChanged: (m) => setState(() => _method = m),
          ),
        ],
        const SizedBox(height: Gap.md),
        CustomTextField(
          label: 'Note',
          controller: _note,
          optional: true,
          hint: 'e.g. Sibling concession of ₹1,000',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Gap.lg),
        _FeeCalculation(
          fee: fee,
          received: initial.clamp(0, fee <= 0 ? initial : fee),
          schedule: schedule,
        ),
      ],
    ];
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.letter,
    required this.title,
    this.trailing,
  });

  final String letter;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.md),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              letter,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AppTextStyles.title)),
          ?trailing,
        ],
      ),
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.value, required this.hint});

  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Text(value, style: AppTextStyles.amount),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.name, required this.studentId});

  final String name;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name.trim().isEmpty ? '?' : name);
    return Row(
      children: [
        Stack(
          children: [
            AppAvatar(initials: initials, seed: studentId, size: 76),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 14,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student photo', style: AppTextStyles.titleSmall),
              const SizedBox(height: 2),
              Text(
                'Initials are used until a photo is added.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => AppToast.show(
                  context,
                  'Photo upload is not available in this demo.',
                  type: ToastType.info,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Upload photo · not in demo',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Free-form instalment count with −/+ buttons (1–36).
class _InstallmentStepper extends StatelessWidget {
  const _InstallmentStepper({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  void _step(int delta) {
    final current = int.tryParse(controller.text) ?? 1;
    controller.text = '${(current + delta).clamp(1, 36)}';
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.remove_rounded,
          tooltip: 'Fewer instalments',
          onPressed: () => _step(-1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: AppTextStyles.amount.copyWith(fontSize: 18),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            onChanged: (_) => onChanged(),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              final n = int.tryParse(v ?? '') ?? 0;
              if (n < 1 || n > 36) return 'Enter 1 to 36 instalments';
              return null;
            },
            decoration: const InputDecoration(suffixText: 'instalments'),
          ),
        ),
        const SizedBox(width: 12),
        CircleIconButton(
          icon: Icons.add_rounded,
          tooltip: 'More instalments',
          onPressed: () => _step(1),
        ),
      ],
    );
  }
}

class _FeeCalculation extends StatelessWidget {
  const _FeeCalculation({
    required this.fee,
    required this.received,
    required this.schedule,
  });

  final int fee;
  final int received;
  final List<Installment> schedule;

  @override
  Widget build(BuildContext context) {
    final remaining = (fee - received).clamp(0, fee);
    return CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVE CALCULATION',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textOnCreamMuted,
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Total agreed',
                  value: Fmt.currency(fee),
                  onCream: true,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Received',
                  value: Fmt.currency(received),
                  onCream: true,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Remaining',
                  value: Fmt.currency(remaining),
                  onCream: true,
                  alignEnd: true,
                  valueColor: remaining > 0
                      ? const Color(0xFFB4541F)
                      : const Color(0xFF138A5E),
                ),
              ),
            ],
          ),
          if (schedule.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            const Divider(color: AppColors.creamBorder),
            const SizedBox(height: 10),
            Text(
              schedule.length == 1
                  ? 'Single payment of ${Fmt.currency(schedule.first.amount)} due ${Fmt.date(schedule.first.dueDate)}'
                  : '${schedule.length} instalments of about ${Fmt.currency(schedule.first.amount)}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textOnCream,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            for (final i in schedule.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(
                      '#${i.number}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnCreamMuted,
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        Fmt.date(i.dueDate),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textOnCream,
                        ),
                      ),
                    ),
                    Text(
                      Fmt.currency(i.amount),
                      style: AppTextStyles.amount.copyWith(
                        color: AppColors.textOnCream,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (schedule.length > 4)
              Text(
                '+ ${schedule.length - 4} more',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textOnCreamMuted,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
