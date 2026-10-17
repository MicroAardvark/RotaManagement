/// A person in the staff list (GET /api/employees/current).
class Employee {
  final String id;
  final String name;
  final String role;

  /// False until a manager has filled in every required personal
  /// detail. Older records start false.
  final bool detailsComplete;

  /// Changes whenever their photo changes; null when there's none.
  final String? photoVersion;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    this.detailsComplete = true,
    this.photoVersion,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      detailsComplete: json['detailsComplete'] as bool? ?? true,
      photoVersion: json['photoVersion'] as String?,
    );
  }
}
