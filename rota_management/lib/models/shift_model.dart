import 'package:intl/intl.dart';

/// Represents a single scheduled shift, as returned by the backend.
class Shift {
  final String id;
  final String employeeId;
  final DateTime startTime;
  final DateTime endTime;
  final String role;
  final String notes;
  final String clientId;
  final String clientName;
  final String clientHouseNumber;
  final String clientAddressLine1;
  final String clientPostcode;
  final String jobTypeId;
  final String clientAccess;

  /// False for drafts, which only managers can see.
  final bool published;

  /// A published shift that changed since the week was last published.
  final bool notifyPending;

  String get clientFullAddress =>
    clientHouseNumber.isEmpty && clientAddressLine1.isEmpty && clientPostcode.isEmpty
        ? ''
        : '$clientHouseNumber $clientAddressLine1, $clientPostcode';

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
    required this.clientName,
    required this.clientId,
    required this.clientHouseNumber,
    required this.clientAddressLine1,
    required this.clientPostcode,
    this.jobTypeId = '',
    this.employeeName,
    required this.clientAccess,
    this.published = true,
    this.notifyPending = false,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    // employeeId can be a plain string OR a populated object
    // ({_id, name, role}) depending on which endpoint returned it.
    final rawEmployeeId = json['employeeId'];
    final clientJson = json['clientId'];
    final isPopulated = clientJson is Map<String, dynamic>;
    String employeeId;
    String? employeeName;

    if (rawEmployeeId is Map<String, dynamic>) {
      employeeId = rawEmployeeId['_id'] as String? ?? '';
      employeeName = rawEmployeeId['name'] as String?;
    } else {
      // Null when the staff member no longer exists
      employeeId = rawEmployeeId as String? ?? '';
    }

    final startTime = DateTime.parse(json['startTime'] as String).toLocal();
    final endRaw = json['endTime'] as String?;
    final endTime = endRaw == null ? startTime : DateTime.parse(endRaw).toLocal();

    return Shift(
      id: json['_id'] as String,
      employeeId: employeeId,
      startTime: startTime,
      endTime: endTime,
      role: json['role'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      employeeName: employeeName,
      clientId: isPopulated ? (clientJson['_id'] as String? ?? '') : (clientJson as String? ?? ''),
      clientName: isPopulated ? (clientJson['name'] as String? ?? '') : '',
      clientHouseNumber: isPopulated ? (clientJson['houseNumber'] as String? ?? '') : '',
      clientAddressLine1: isPopulated ? (clientJson['addressLine1'] as String? ?? '') : '',
      clientPostcode: isPopulated ? (clientJson['postcode'] as String? ?? '') : '',
      jobTypeId: json['jobTypeId'] as String? ?? '',
      clientAccess: isPopulated ? (clientJson['access'] as String? ?? '') : '',
      published: json['published'] as bool? ?? true,
      notifyPending: json['notifyPending'] as bool? ?? false,
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