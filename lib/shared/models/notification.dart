enum NotificationType {
  attendance,
  exam,
  student,
  messageFailed,
  payment,
  staff,
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.adminOnly = false,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  bool isRead;
  final bool adminOnly;
}

enum ActivityType { attendance, payment, exam, staff, student, message }

/// An entry on the dashboard's "Today's activity" feed.
class ActivityEvent {
  const ActivityEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.at,
    this.adminOnly = false,
  });

  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime at;
  final bool adminOnly;
}
