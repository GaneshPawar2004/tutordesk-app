import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

/// Bottom sheet to switch the academic year used across the app.
Future<void> showAcademicYearSheet(BuildContext context) async {
  final app = context.appRead;
  final picked = await showSelectSheet<String>(
    context,
    title: 'Academic year',
    subtitle:
        'Used for student lists, fees and reports. Today\'s attendance always uses the current year.',
    options: [
      for (final y in app.academic.years)
        SelectOption(
          y.id,
          y.label,
          subtitle:
              '${y.status.label} · ${Fmt.shortDate(y.startDate)} ${y.startDate.year} – ${Fmt.date(y.endDate)}',
          icon: y.status == YearStatus.active
              ? Icons.event_available_rounded
              : Icons.calendar_month_outlined,
        ),
    ],
    selected: app.selectedYear.id,
  );
  if (picked != null && context.mounted) {
    app.selectYear(picked.value);
    AppToast.show(
      context,
      'Showing academic year ${picked.label}',
      type: ToastType.info,
    );
  }
}
