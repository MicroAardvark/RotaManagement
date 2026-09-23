class JobType {
  final String id;
  final String name;
  final int lengthMinutes;

  JobType({required this.id, required this.name, required this.lengthMinutes});

  factory JobType.fromJson(Map<String, dynamic> json) {
    return JobType(
      id: json['_id'] as String,
      name: json['name'] as String,
      lengthMinutes: json['lengthMinutes'] as int,
    );
  }
}