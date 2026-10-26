enum UserRole {
  admin('Owner · Admin'),
  staff('Staff');

  const UserRole(this.label);
  final String label;
}

class Tuition {
  Tuition({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.phone,
    required this.email,
  });

  final String id;
  String name;
  String city;
  String address;
  String phone;
  String email;
}

/// The admin account for the tuition (single owner in this phase).
class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  final String id;
  String name;
  String email;
  String phone;

  String get firstName => name.split(' ').first;
}

/// Toggleable permissions an admin can grant to staff.
///
/// Fees, payments and financial reports are intentionally absent: they are
/// admin-only by product policy and cannot be granted.
enum StaffPermission {
  viewStudents(
    'View student profiles',
    'See student details and parent contacts for assigned classes',
  ),
  markAttendance(
    'Mark attendance',
    'Take and save attendance for assigned classes',
  ),
  viewExamResults(
    'View exam results',
    'Open exams and published results for assigned classes',
  ),
  enterMarks('Enter marks', 'Enter and save draft marks for exams'),
  sendParentMessages(
    'Send parent messages',
    'Open the Messages centre and prepare parent notifications',
  ),
  sendSms(
    'Send SMS notifications',
    'Allow prepared messages to be queued for SMS delivery',
  ),
  editStudents(
    'Edit student information',
    'Update student and parent details (no fee access)',
  );

  const StaffPermission(this.label, this.description);
  final String label;
  final String description;
}

enum AccountStatus {
  active('Active'),
  invitationPending('Invitation pending');

  const AccountStatus(this.label);
  final String label;
}

class StaffMember {
  StaffMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.designation,
    required this.assignedClassIds,
    required this.permissions,
    required this.joinedOn,
    this.isActive = true,
    this.accountStatus = AccountStatus.active,
  });

  final String id;
  String name;
  String phone;
  String email;
  String designation;
  List<String> assignedClassIds;
  Set<StaffPermission> permissions;
  DateTime joinedOn;
  bool isActive;
  AccountStatus accountStatus;

  String get firstName => name.split(' ').first;

  String get initials => _initials(name);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

String initialsOf(String name) => _initials(name);
