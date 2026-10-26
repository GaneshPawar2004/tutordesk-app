import 'user.dart';

enum Gender {
  female('Female'),
  male('Male'),
  other('Other');

  const Gender(this.label);
  final String label;
}

/// Permanent student identity. Never duplicated across academic years.
class Student {
  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.parentName,
    required this.parentPhone,
    required this.admittedOn,
    this.gender,
    this.altPhone,
    this.address,
    this.isActive = true,
  });

  /// Human-readable permanent ID, e.g. STU-0001.
  final String id;
  String firstName;
  String lastName;
  DateTime dateOfBirth;
  Gender? gender;
  String parentName;
  String parentPhone;
  String? altPhone;
  String? address;
  DateTime admittedOn;
  bool isActive;

  String get fullName => '$firstName $lastName';

  String get initials => initialsOf(fullName);

  int ageOn(DateTime date) {
    var age = date.year - dateOfBirth.year;
    final hadBirthday =
        date.month > dateOfBirth.month ||
        (date.month == dateOfBirth.month && date.day >= dateOfBirth.day);
    if (!hadBirthday) age--;
    return age;
  }
}
