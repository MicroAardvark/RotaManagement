class Employee {
  final String id;
  final String name;
  final String role;

  Employee({required this.id, required this.name, required this.role});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }
}