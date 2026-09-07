import 'package:intl/intl.dart';

/// Represents a single scheduled shift, as returned by the backend.
class Shift {
  final String id;
  final String employeeId;
  final DateTime startTime;
  final DateTime endTime;
  final String role;
  final String notes;

  // Only populated when returned from the manager's company-wide
  // endpoint (employeeId is populated with name/role there).
  final String? employeeName;

  Shift({
    required this.id,
    required this.employeeId,
    required this.startTime,
    required this.endTime,
    this.role = '',
    this.notes = '',
    this.employeeName,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    // employeeId can be a plain string OR a populated object
    // ({_id, name, role}) depending on which endpoint returned it.
    final rawEmployeeId = json['employeeId'];
    String employeeId;
    String? employeeName;

    if (rawEmployeeId is Map<String, dynamic>) {
      employeeId = rawEmployeeId['_id'] as String;
      employeeName = rawEmployeeId['name'] as String?;
    } else {
      employeeId = rawEmployeeId as String;
    }

    return Shift(
      id: json['_id'] as String,
      employeeId: employeeId,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      role: json['role'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      employeeName: employeeName,
    );
  }

  /// UK-style formatted date/time, e.g. "Tue 9 Sep, 09:00–17:00"
  String get formattedDate {
    final datePart = DateFormat('EEE d MMM').format(startTime);
    final startPart = DateFormat('HH:mm').format(startTime);
    final endPart = DateFormat('HH:mm').format(endTime);
    return '$datePart, $startPart–$endPart';
  }
}