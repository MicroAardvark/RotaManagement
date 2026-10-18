String _str(dynamic value) => value is String ? value : '';

/// What the add/edit staff sheet sends to the API.
class StaffInput {
  final String name;
  final String email; // ignored when editing
  final String role;

  const StaffInput({required this.name, required this.email, required this.role});

  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'role': role};
}

/// One person's record (GET /api/employees/:id).
class StaffRecord {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool passwordSet;
  final String? photoVersion;

  const StaffRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.passwordSet,
    required this.photoVersion,
  });

  factory StaffRecord.fromJson(Map<String, dynamic> employee) => StaffRecord(
        id: employee['_id'] as String,
        name: _str(employee['name']),
        email: _str(employee['email']),
        role: _str(employee['role']).isEmpty ? 'employee' : _str(employee['role']),
        passwordSet: employee['passwordSet'] == true,
        photoVersion: employee['photoVersion'] as String?,
      );
}
