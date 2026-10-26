import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/message_templates.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'batch_detail_screen.dart';
import 'message_widgets.dart';

enum _Target {
  all('All parents'),
  classes('Selected classes'),
  parents('Selected parents');

  const _Target(this.label);
  final String label;
}

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  /// One key per composer: repeated taps resolve to the same batch.
  final _draftKey = 'ann-${DateTime.now().microsecondsSinceEpoch}';
  var _target = _Target.all;
  final _classIds = <String>{};
  final _studentIds = <String>{};
  var _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  List<Student> _recipients() {
    final app = context.appRead;
    final classes = app.visibleClasses;
    return switch (_target) {
      _Target.all => [for (final c in classes) ...app.rosterFor(c.id)],
      _Target.classes => [
        for (final c in classes.where((c) => _classIds.contains(c.id)))
          ...app.rosterFor(c.id),
      ],
      _Target.parents => [
        for (final c in classes)
          ...app.rosterFor(c.id).where((s) => _studentIds.contains(s.id)),
      ],
    };
  }

  Future<void> _pickClasses() async {
    final app = context.appRead;
    final picked = await showMultiSelectSheet<String>(
      context,
      title: 'Select classes',
      options: [
        for (final c in app.visibleClasses)
          SelectOption(
            c.id,
            c.name,
            subtitle: Fmt.plural(app.rosterFor(c.id).length, 'parent'),
          ),
      ],
      selected: _classIds,
    );
    if (picked != null) {
      setState(
        () => _classIds
          ..clear()
          ..addAll(picked),
      );
    }
  }

  Future<void> _pickParents() async {
    final app = context.appRead;
    final picked = await showMultiSelectSheet<String>(
      context,
      title: 'Select parents',
      options: [
        for (final c in app.visibleClasses)
          for (final s in app.rosterFor(c.id))
            SelectOption(
              s.id,
              s.fullName,
              subtitle:
                  '${c.name} · ${s.parentName} · ${Fmt.phoneSuffix(s.parentPhone)}',
            ),
      ],
      selected: _studentIds,
    );
    if (picked != null) {
      setState(
        () => _studentIds
          ..clear()
          ..addAll(picked),
      );
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) return;
    final recipients = _recipients();
    if (recipients.isEmpty) {
      AppToast.show(
        context,
        'Choose at least one recipient.',
        type: ToastType.error,
      );
      return;
    }
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Send announcement?',
      message:
          '"${_title.text.trim()}" will be queued for ${Fmt.plural(recipients.length, 'parent')}. '
          'Demo only — no real SMS is sent.',
      confirmLabel: 'Confirm & send',
      icon: Icons.campaign_outlined,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    final app = context.appRead;
    final classIds = recipients
        .map((s) => app.enrollmentOf(s.id, app.currentYear.id)!.classId)
        .toSet()
        .toList();
    final result = app.sendAnnouncement(
      draftKey: _draftKey,
      title: _title.text.trim(),
      body: _body.text.trim(),
      classIds: classIds,
      selected: recipients,
    );
    replacePage(context, BatchDetailScreen(batchId: result.batch.id));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.canSendMessages) {
      return const AppScaffold(
        title: 'Announcement',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Sending disabled',
          message: 'SMS sending is not enabled for your account.',
        ),
      );
    }
    final recipients = _recipients();
    final preview = MessageTemplates.announcement(
      _title.text.trim().isEmpty ? '[Title]' : _title.text.trim(),
      _body.text.trim().isEmpty ? '[Your message]' : _body.text.trim(),
      app.tuition.name,
    );
    final recent = app.visibleBatches
        .where((b) => b.category == MessageCategory.announcement)
        .take(3)
        .toList();

    return AppScaffold(
      title: 'New announcement',
      subtitle: app.tuition.name,
      bottomBar: PrimaryButton(
        label: 'Review & send · ${Fmt.plural(recipients.length, 'parent')}',
        icon: Icons.send_rounded,
        loading: _sending,
        onPressed: recipients.isEmpty ? null : _send,
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
            const SmsDemoBanner(),
            const SizedBox(height: Gap.lg),
            CustomTextField(
              label: 'Announcement title',
              controller: _title,
              hint: 'e.g. Saturday batch timing change',
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Enter a short title' : null,
            ),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Message',
              controller: _body,
              hint: 'What should parents know?',
              maxLines: 5,
              maxLength: 320,
              textCapitalization: TextCapitalization.sentences,
              helper: '${_body.text.length}/320 characters',
              onChanged: (_) => setState(() {}),
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Write at least a sentence'
                  : null,
            ),
            const SizedBox(height: Gap.lg),
            const FieldLabel('Target audience'),
            SegmentedChoice<_Target>(
              options: [
                for (final t in _Target.values) SelectOption(t, t.label),
              ],
              value: _target,
              onChanged: (t) => setState(() => _target = t),
            ),
            if (_target == _Target.classes) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                label: _classIds.isEmpty
                    ? 'Choose classes'
                    : _classIds
                          .map((id) => app.academic.classById(id).name)
                          .join(', '),
                icon: Icons.class_outlined,
                onPressed: _pickClasses,
              ),
            ],
            if (_target == _Target.parents) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                label: _studentIds.isEmpty
                    ? 'Choose parents'
                    : '${Fmt.plural(_studentIds.length, 'parent')} selected',
                icon: Icons.people_outline_rounded,
                onPressed: _pickParents,
              ),
            ],
            const SizedBox(height: Gap.md),
            Row(
              children: [
                const Icon(
                  Icons.groups_2_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estimated recipients: ${recipients.length}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SectionHeader(
              title: 'Preview',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
            ),
            MessageBubble(text: preview),
            if (recent.isNotEmpty) ...[
              const SectionHeader(
                title: 'Recent announcements',
                padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
              ),
              for (final b in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BatchTile(
                    batch: b,
                    onTap: () =>
                        pushPage(context, BatchDetailScreen(batchId: b.id)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
