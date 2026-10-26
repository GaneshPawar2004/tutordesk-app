import '../../shared/models/models.dart';
import 'mock_repository.dart';

/// In-app notifications and the dashboard activity feed.
class NotificationRepository extends MockRepository {
  NotificationRepository(
    super.onChanged, {
    required this._notifications,
    required this._activity,
  });

  final List<AppNotification> _notifications;
  final List<ActivityEvent> _activity;
  var _counter = 1000;

  List<AppNotification> visible({required bool isAdmin}) =>
      _notifications.where((n) => isAdmin || !n.adminOnly).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadCount({required bool isAdmin}) =>
      visible(isAdmin: isAdmin).where((n) => !n.isRead).length;

  void add({
    required NotificationType type,
    required String title,
    required String body,
    bool adminOnly = false,
  }) {
    _notifications.add(
      AppNotification(
        id: 'ntf-${++_counter}',
        type: type,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        adminOnly: adminOnly,
      ),
    );
    changed();
  }

  void markRead(AppNotification n) {
    if (n.isRead) return;
    n.isRead = true;
    changed();
  }

  void markAllRead({required bool isAdmin}) {
    for (final n in visible(isAdmin: isAdmin)) {
      n.isRead = true;
    }
    changed();
  }

  List<ActivityEvent> activity({required bool isAdmin}) =>
      _activity.where((a) => isAdmin || !a.adminOnly).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  void log(ActivityEvent event) {
    _activity.add(event);
    changed();
  }
}
