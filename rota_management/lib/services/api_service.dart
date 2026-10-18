import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/client_model.dart';
import '../models/employee_model.dart';
import '../models/job_type_model.dart';
import '../models/shift_model.dart';
import '../models/staff_details.dart';
import '../navigation.dart';
import 'http_client.dart';
import 'session_store.dart';

/// How many changes publishing a week would send out.
class WeekStatus {
  final int pendingShifts;
  final int pendingRemovals;
  final DateTime? publishedAt;

  const WeekStatus({
    required this.pendingShifts,
    required this.pendingRemovals,
    this.publishedAt,
  });

  int get pendingTotal => pendingShifts + pendingRemovals;
}

/// Result of publishing a week.
class PublishResult {
  final int emailed;
  final int failed;

  const PublishResult({required this.emailed, required this.failed});
}

class ApiService {
  /// Defaults to the origin the web app was loaded from, so the
  /// production build needs no config. Override for local development
  /// with --dart-define=API_BASE_URL=http://localhost:3000
  static const String _apiOverride = String.fromEnvironment('API_BASE_URL');
  static final String baseUrl =
      _apiOverride.isNotEmpty ? _apiOverride : Uri.base.origin;

  /// The session lives in an httpOnly cookie the server sets, so this
  /// app never sees or stores the token. On web this client sends the
  /// cookie with every request.
  static final http.Client _client = createHttpClient();

  /// Every request carries this header; the server refuses cookie
  /// requests that change data without it (CSRF protection).
  static const Map<String, String> _baseHeaders = {'X-Requested-With': 'RotaApp'};
  static const Map<String, String> _jsonHeaders = {
    'X-Requested-With': 'RotaApp',
    'Content-Type': 'application/json',
  };

  /// Only used to delete tokens saved by older builds of the app.
  static const _legacyStorage = FlutterSecureStorage();

  static bool _redirectingToLogin = false;

  // ---- Plumbing ----

  static Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  static Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool redirectOn401 = true,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(body == null ? _baseHeaders : _jsonHeaders);
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await _client.send(request));
    if (response.statusCode == 401 && redirectOn401) _sessionExpired();
    return response;
  }

  /// Any 401 means the session has ended (expired, logged out elsewhere,
  /// password changed or account deactivated): go to the login screen.
  static void _sessionExpired() {
    SessionStore.instance.clear();
    if (_redirectingToLogin) return;
    _redirectingToLogin = true;
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    Future<void>.delayed(const Duration(seconds: 2), () => _redirectingToLogin = false);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{}; // e.g. an nginx error page
    }
  }

  static bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  static ApiException _failure(http.Response response, String fallback) {
    final data = _decode(response);
    final rawFields = data['fields'];
    final fields = <String, String>{};
    if (rawFields is Map) {
      rawFields.forEach((key, value) => fields[key.toString()] = value.toString());
    }
    return ApiException(
      statusCode: response.statusCode,
      message: (data['error'] as String?) ?? (data['message'] as String?) ?? fallback,
      fields: fields,
    );
  }

  /// Sends a request and returns the decoded body, or throws ApiException.
  static Future<Map<String, dynamic>> _json(
    String method,
    String path,
    String fallback, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final response = await _send(method, path, body: body, query: query);
    if (_ok(response)) return _decode(response);
    throw _failure(response, fallback);
  }

  static Future<Map<String, dynamic>> _upload(
    String path,
    Uint8List bytes,
    String filename,
    String fallback,
  ) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_baseHeaders)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final response = await http.Response.fromStream(await _client.send(request));
    if (response.statusCode == 401) _sessionExpired();
    if (response.statusCode == 413) {
      throw ApiException(statusCode: 413, message: 'That file is too large. The limit is 5 MB.');
    }
    if (_ok(response)) return _decode(response);
    throw _failure(response, fallback);
  }

  static List<Map<String, dynamic>> _list(dynamic value) =>
      value is List ? value.whereType<Map<String, dynamic>>().toList() : [];

  static Future<void> _clearLegacyToken() async {
    try {
      await _legacyStorage.delete(key: 'jwt_token');
      await _legacyStorage.delete(key: 'user_role');
    } catch (_) {
      // Nothing to clean up
    }
  }

  // ---- Auth ----

  /// Logs in. [remember] is the "Keep me signed in" tick box: the
  /// session cookie then lasts 30 days instead of ending when the
  /// browser closes.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    final response = await _send(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password, 'remember': remember},
      redirectOn401: false,
    );
    if (response.statusCode == 200) {
      await _clearLegacyToken();
      await getMe();
      return _decode(response);
    }
    throw _failure(response, 'Login failed.');
  }

  /// Who is logged in, or null if nobody. Also updates [SessionStore].
  static Future<CurrentUser?> getMe() async {
    final response = await _send('GET', '/api/auth/me', redirectOn401: false);
    if (response.statusCode == 200) {
      final user = CurrentUser.fromJson(_decode(response));
      SessionStore.instance.setUser(user);
      return user;
    }
    if (response.statusCode == 401) {
      SessionStore.instance.clear();
      return null;
    }
    throw _failure(response, 'Could not check your login.');
  }

  static Future<void> logout() async {
    try {
      await _send('POST', '/api/auth/logout', redirectOn401: false);
    } finally {
      SessionStore.instance.clear();
      await _clearLegacyToken();
    }
  }

  static Future<bool> checkManager() async {
    final response = await _send('GET', '/api/employees/check-manager');
    if (response.statusCode == 200) return _decode(response)['isManager'] == true;
    return false;
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _send(
      'POST',
      '/api/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      redirectOn401: false, // a wrong current password must not log you out
    );
    if (response.statusCode == 200) return; // server re-issued the cookie

    final data = _decode(response);
    throw ChangePasswordException(
      statusCode: response.statusCode,
      message: (data['error'] as String?) ?? (data['message'] as String?) ?? 'Failed to change password',
      field: data['field'] as String?,
    );
  }

  /// Manager-only: emails a bug report or feature request to the
  /// app's support address. [priority] is 'high', 'medium' or 'low'.
  static Future<void> sendFeedback({required String priority, required String details}) async {
    await _json('POST', '/api/feedback', 'Failed to send your report',
        body: {'priority': priority, 'details': details});
  }

  static Future<void> requestPasswordReset(String email) async {
    await _json('POST', '/api/auth/forgot-password', 'Failed to send the reset link',
        body: {'email': email});
  }

  // ---- Profile photo ----

  /// Uploads your own profile photo. Returns the new photo version.
  static Future<String?> uploadProfilePhoto(Uint8List bytes, String filename) async {
    final data = await _upload('/api/auth/me/photo', bytes, filename, 'Failed to update photo');
    return data['photoVersion'] as String?;
  }

  static Future<void> removeProfilePhoto() async {
    await _json('DELETE', '/api/auth/me/photo', 'Failed to remove photo');
  }

  /// URL of someone's photo. The version makes it change whenever the
  /// photo does, so the browser can cache it safely.
  static String photoUrl(String staffId, String version) =>
      '$baseUrl/api/employees/$staffId/photo?v=${Uri.encodeComponent(version)}';

  // ---- Staff ----

  /// Manager-only staff list. Empty for non-managers.
  static Future<List<Employee>> getCurrentEmployees() async {
    final response = await _send('GET', '/api/employees/current');
    if (response.statusCode == 200) {
      return _list(_decode(response)['employees']).map(Employee.fromJson).toList();
    }
    if (response.statusCode == 403) return [];
    throw _failure(response, 'Failed to load employees');
  }

  static Future<StaffRecord> getStaffDetails(String staffId) async {
    final data = await _json('GET', '/api/employees/$staffId', 'Failed to load employee');
    final employee = data['employee'];
    if (employee is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Failed to load employee');
    }
    return StaffRecord.fromJson(employee);
  }

  /// Manager-only: adds someone and emails them an invite. Returns their id.
  static Future<String> createEmployee(StaffInput input) async {
    final data = await _json('POST', '/api/employees', 'Failed to create employee', body: input.toJson());
    final employee = data['employee'];
    if (employee is Map<String, dynamic> && employee['id'] is String) {
      return employee['id'] as String;
    }
    throw ApiException(statusCode: 500, message: 'Employee added, but the reply was unexpected. Refresh the list.');
  }

  static Future<void> updateStaff(String staffId, StaffInput input) async {
    await _json('PUT', '/api/employees/$staffId', 'Failed to save changes', body: input.toJson());
  }

  static Future<void> resendInvite(String employeeId) async {
    await _json('POST', '/api/employees/$employeeId/resend-invite', 'Failed to resend invite');
  }

  /// Returns how many upcoming shifts were removed.
  static Future<int> deactivateEmployee(String employeeId) async {
    final data = await _json('POST', '/api/employees/$employeeId/deactivate', 'Failed to deactivate employee');
    return (data['removedShifts'] as num?)?.toInt() ?? 0;
  }

  // ---- Shifts ----

  static Future<Shift?> getNextShift() async {
    final data = await _json('GET', '/api/shifts/next', 'Failed to load next shift');
    final shiftJson = data['shift'];
    return shiftJson is Map<String, dynamic> ? Shift.fromJson(shiftJson) : null;
  }

  /// The current user's upcoming published shifts.
  static Future<List<Shift>> getMyShifts() async {
    final data = await _json('GET', '/api/shifts/mine', 'Failed to load shifts');
    return _list(data['shifts']).map(Shift.fromJson).toList();
  }

  /// Manager-only: every upcoming shift for the company, drafts included.
  static Future<List<Shift>> getCompanyShifts() async {
    final response = await _send('GET', '/api/shifts/company');
    if (response.statusCode == 200) {
      return _list(_decode(response)['shifts']).map(Shift.fromJson).toList();
    }
    if (response.statusCode == 403) return [];
    throw _failure(response, 'Failed to load company shifts');
  }

  /// [endTime] is the finish time the manager chose. Leave it null to
  /// let the server use the job type's length.
  static Future<Shift> createShift({
    required String employeeId,
    required DateTime startTime,
    DateTime? endTime,
    required String jobTypeId,
    required String clientId,
    String notes = '',
  }) async {
    final data = await _json('POST', '/api/shifts', 'Failed to create shift', body: {
      'employeeId': employeeId,
      'startTime': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'endTime': endTime.toUtc().toIso8601String(),
      'jobTypeId': jobTypeId,
      'clientId': clientId,
      'notes': notes,
    });
    return Shift.fromJson(data['shift'] as Map<String, dynamic>);
  }

  static Future<Shift> updateShift({
    required String id,
    required String employeeId,
    required DateTime startTime,
    DateTime? endTime,
    required String jobTypeId,
    required String clientId,
    String notes = '',
  }) async {
    final data = await _json('PUT', '/api/shifts/$id', 'Failed to update shift', body: {
      'employeeId': employeeId,
      'startTime': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'endTime': endTime.toUtc().toIso8601String(),
      'jobTypeId': jobTypeId,
      'clientId': clientId,
      'notes': notes,
    });
    return Shift.fromJson(data['shift'] as Map<String, dynamic>);
  }

  static Future<void> deleteShift(String id) async {
    await _json('DELETE', '/api/shifts/$id', 'Failed to delete shift');
  }

  /// Local Monday 00:00 to the next Monday 00:00 as UTC strings. Built
  /// from calendar dates rather than adding 7 days, so weeks with a
  /// clock change are still exactly Monday to Monday.
  static Map<String, String> _weekRange(DateTime monday) {
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = DateTime(monday.year, monday.month, monday.day + 7);
    return {
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    };
  }

  /// The Monday of the week [day] falls in.
  static DateTime mondayOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

  static Future<WeekStatus> getWeekStatus(DateTime monday) async {
    final data = await _json('GET', '/api/shifts/week-status', 'Failed to load week status',
        query: _weekRange(monday));
    return WeekStatus(
      pendingShifts: (data['pendingShifts'] as num?)?.toInt() ?? 0,
      pendingRemovals: (data['pendingRemovals'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse(data['publishedAt'] as String? ?? '')?.toLocal(),
    );
  }

  /// Publishes the week starting [monday] and emails affected staff.
  static Future<PublishResult> publishWeek(DateTime monday) async {
    final data = await _json('POST', '/api/shifts/publish', 'Failed to publish the rota',
        body: _weekRange(monday));
    return PublishResult(
      emailed: (data['emailed'] as num?)?.toInt() ?? 0,
      failed: (data['failed'] as num?)?.toInt() ?? 0,
    );
  }

  // ---- Job types ----

  static Future<List<JobType>> getJobTypes() async {
    final data = await _json('GET', '/api/company/job-types', 'Failed to fetch job types');
    return _list(data['jobTypes']).map(JobType.fromJson).toList();
  }

  static Future<JobType> addJobType(String name) async {
    final data = await _json('POST', '/api/company/job-types', 'Failed to add job type',
        body: {'name': name});
    return JobType.fromJson(data['jobType'] as Map<String, dynamic>);
  }

  static Future<JobType> updateJobType(String id, String name) async {
    final data = await _json('PUT', '/api/company/job-types/$id', 'Failed to update job type',
        body: {'name': name});
    return JobType.fromJson(data['jobType'] as Map<String, dynamic>);
  }

  static Future<void> deleteJobType(String id) async {
    await _json('DELETE', '/api/company/job-types/$id', 'Failed to delete job type');
  }

  // ---- Clients ----

  static Future<List<Client>> getClients() async {
    final data = await _json('GET', '/api/clients', 'Failed to fetch clients');
    return _list(data['clients']).map(Client.fromJson).toList();
  }

  static Future<Client> addClient({
    required String name,
    required String houseNumber,
    required String addressLine1,
    required String postcode,
    required String phone,
    required String email,
    required String access,
  }) async {
    final data = await _json('POST', '/api/clients', 'Failed to add client', body: {
      'name': name,
      'houseNumber': houseNumber,
      'addressLine1': addressLine1,
      'postcode': postcode,
      'phone': phone,
      'email': email,
      'access': access,
    });
    return Client.fromJson(data['client'] as Map<String, dynamic>);
  }

  static Future<Client> updateClient({
    required String id,
    required String name,
    required String houseNumber,
    required String addressLine1,
    required String postcode,
    required String phone,
    required String email,
    required String access,
  }) async {
    final data = await _json('PUT', '/api/clients/$id', 'Failed to update client', body: {
      'name': name,
      'houseNumber': houseNumber,
      'addressLine1': addressLine1,
      'postcode': postcode,
      'phone': phone,
      'email': email,
      'access': access,
    });
    return Client.fromJson(data['client'] as Map<String, dynamic>);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Per-field validation errors from the server, keyed by field path
  /// (e.g. 'email'). Empty when there are none.
  final Map<String, String> fields;

  ApiException({required this.statusCode, required this.message, this.fields = const {}});

  @override
  String toString() => message;
}

class ChangePasswordException extends ApiException {
  final String? field;

  ChangePasswordException({
    required super.statusCode,
    required super.message,
    this.field,
  });
}
