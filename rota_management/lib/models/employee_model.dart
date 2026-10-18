/// A person in the staff list (GET /api/employees/current).
class Employee {
  final String id;
  final String name;
  final String role;

  /// Changes whenever their photo changes; null when there's none.
  final String? photoVersion;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    this.photoVersion,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      photoVersion: json['photoVersion'] as String?,
    );
  }
}
