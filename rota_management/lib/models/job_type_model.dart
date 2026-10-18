class JobType {
  final String id;
  final String name;

  JobType({required this.id, required this.name});

  factory JobType.fromJson(Map<String, dynamic> json) {
    return JobType(
      id: json['_id'] as String,
      name: json['name'] as String,
    );
  }
}
