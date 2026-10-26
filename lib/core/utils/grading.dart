import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class Grade {
  const Grade(this.label, this.remark, this.color);

  final String label;
  final String remark;
  final Color color;
}

/// Grade bands used across result screens and parent messages.
Grade gradeFor(double percent) {
  if (percent >= 90) return const Grade('A+', 'Outstanding', AppColors.success);
  if (percent >= 75) return const Grade('A', 'Excellent', AppColors.success);
  if (percent >= 60) return const Grade('B', 'Good', AppColors.accent);
  if (percent >= 45) return const Grade('C', 'Satisfactory', AppColors.info);
  if (percent >= 35) return const Grade('D', 'Pass', AppColors.warning);
  return const Grade('E', 'Needs improvement', AppColors.error);
}
