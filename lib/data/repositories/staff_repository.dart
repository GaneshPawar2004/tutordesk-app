import '../../shared/models/models.dart';
import 'mock_repository.dart';

class StaffRepository extends MockRepository {
  StaffRepository(super.onChanged, {required this._staff});

  final List<StaffMember> _staff;
  var _counter = 100;

  List<StaffMember> get all => List.unmodifiable(_staff);

  StaffMember byId(String id) => _staff.firstWhere((s) => s.id == id);

  List<StaffMember> forClass(String classId) =>
      _staff.where((s) => s.assignedClassIds.contains(classId)).toList();

  StaffMember add({
    required String name,
    required String email,
    required String phone,
    required String designation,
    required List<String> classIds,
    required bool isActive,
  }) {
    final member = StaffMember(
      id: 'stf-${++_counter}',
      name: name,
      email: email,
      phone: phone,
      designation: designation,
      assignedClassIds: classIds,
      isActive: isActive,
      // Sensible defaults for a new teacher. Never any financial access.
      permissions: {
        StaffPermission.viewStudents,
        StaffPermission.markAttendance,
        StaffPermission.viewExamResults,
      },
      joinedOn: DateTime.now(),
      accountStatus: AccountStatus.invitationPending,
    );
    _staff.add(member);
    changed();
    return member;
  }

  void update(
    StaffMember member, {
    required String name,
    required String email,
    required String phone,
    required String designation,
    required List<String> classIds,
    required bool isActive,
  }) {
    member
      ..name = name
      ..email = email
      ..phone = phone
      ..designation = designation
      ..assignedClassIds = classIds
      ..isActive = isActive;
    changed();
  }

  void setPermission(
    StaffMember member,
    StaffPermission permission,
    bool granted,
  ) {
    if (granted) {
      member.permissions.add(permission);
    } else {
      member.permissions.remove(permission);
    }
    changed();
  }

  /// Sets exactly which staff are assigned to [classId].
  void assignToClass(String classId, Set<String> staffIds) {
    for (final s in _staff) {
      final has = s.assignedClassIds.contains(classId);
      final should = staffIds.contains(s.id);
      if (should && !has) s.assignedClassIds = [...s.assignedClassIds, classId];
      if (!should && has) {
        s.assignedClassIds = s.assignedClassIds
            .where((c) => c != classId)
            .toList();
      }
    }
    changed();
  }

  void markInvitationAccepted(StaffMember member) {
    member.accountStatus = AccountStatus.active;
    changed();
  }
}
