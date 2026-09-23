import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/employee_model.dart';
import '../models/shift_model.dart';
import '../models/job_type_model.dart';
import '../models/client_model.dart';

class ApiService {
  static const String baseUrl = 'https://rota.princecleaning.co.uk';

  static const _storage = FlutterSecureStorage();

  // ---- Token helpers ----

  static Future<String?> getToken() => _storage.read(key: 'jwt_token');

  static Future<String?> getRole() => _storage.read(key: 'user_role');

  static Future<void> clearSession() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
  }

  // ---- Auth endpoints ----

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      await _storage.write(key: 'jwt_token', value: data['token'] as String);
      await _storage.write(key: 'user_role', value: data['role'] as String);
      return data;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: (data['message'] as String?) ?? 'Login failed.',
    );
  }

  static Future<bool> checkManager() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/employees/check-manager'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await getToken()}',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if(data['isManager']) {
        return true;
      }
    }
    return false;
  }

  // Manager-only — requires a valid manager JWT to already be stored
  

  static Future<List<Employee>> getCurrentEmployees() async {
    final token = await getToken(); // however you retrieve the JWT

    final response = await http.get(
      Uri.parse('$baseUrl/api/employees/current'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final employeesJson = data['employees'] as List<dynamic>;
      return employeesJson
          .map((e) => Employee.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 403) {
      // Not a manager, or no company association - not an error state,
      // just means this user shouldn't see the list. HomeScreen already
      // guards this client-side, but handle gracefully in case of a
      // race condition or stale isManager flag.
      return [];
    } else {
      throw Exception('Failed to load employees (${response.statusCode})');
    }
  }

  // ---- Shift endpoints ----
  static Future<Shift?> getNextShift() async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/api/shifts/next'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final shiftJson = data['shift'] as Map<String, dynamic>?;
      return shiftJson != null ? Shift.fromJson(shiftJson) : null;
    } else {
      throw Exception('Failed to load next shift (${response.statusCode})');
    }
  }

  /// Fetches all of the current user's upcoming shifts.
  static Future<List<Shift>> getMyShifts() async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/api/shifts/mine'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final shiftsJson = data['shifts'] as List<dynamic>;
      return shiftsJson
          .map((s) => Shift.fromJson(s as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load shifts (${response.statusCode})');
    }
  }

  /// Manager-only: fetches every upcoming shift for the manager's company.
  static Future<List<Shift>> getCompanyShifts() async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/api/shifts/company'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final shiftsJson = data['shifts'] as List<dynamic>;
      return shiftsJson
          .map((s) => Shift.fromJson(s as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 403) {
      return [];
    } else {
      throw Exception('Failed to load company shifts (${response.statusCode})');
    }
  }

  /// Manager-only: creates a new shift for an employee in their company.
    static Future<Shift> createShift({
    required String employeeId,
    required DateTime startTime,
    required String jobTypeId,
    required String clientId,
    String notes = '',
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/shifts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'employeeId': employeeId,
        'startTime': startTime.toIso8601String(),
        'jobTypeId': jobTypeId,
        'clientId': clientId,
        'notes': notes,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create shift');
    }
    final data = jsonDecode(response.body);
    return Shift.fromJson(data['shift']);
  }

  /// Manager-only: creates a new employee account within the manager's
  /// own company.
  static Future<void> createEmployee({
    required String name,
    required String email,
    required String role,
  }) async {
    final token = await getToken();
 
    final response = await http.post(
      Uri.parse('$baseUrl/api/employees'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'role': role,
      }),
    );
 
    if (response.statusCode == 201) return;
 
    throw ApiException(
      statusCode: response.statusCode,
      message: _errorFrom(response, 'Failed to create employee'),
    );
  }

  static Future<void> resendInvite(String employeeId) async {
    final token = await getToken();
 
    final response = await http.post(
      Uri.parse('$baseUrl/api/employees/$employeeId/resend-invite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
 
    if (response.statusCode == 200) return;
 
    throw ApiException(
      statusCode: response.statusCode,
      message: _errorFrom(response, 'Failed to resend invite'),
    );
  }
 
  /// Pulls the error text out of a JSON error body without crashing if
  /// the body isn't JSON (e.g. an nginx 502 page).
  static String _errorFrom(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['error'] as String?) ?? (data['message'] as String?) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
 


  static Future<List<JobType>> getJobTypes() async {
    final token = await getToken(); // however you retrieve the stored JWT elsewhere
    final response = await http.get(
      Uri.parse('$baseUrl/api/company/job-types'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch job types');
    }
    final data = jsonDecode(response.body);
    return (data['jobTypes'] as List)
        .map((j) => JobType.fromJson(j))
        .toList();
  }

  static Future<JobType> addJobType(String name, int lengthMinutes) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/company/job-types'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'lengthMinutes': lengthMinutes}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to add job type');
    }
    final data = jsonDecode(response.body);
    return JobType.fromJson(data['jobType']);
  }

  static Future<JobType> updateJobType(String id, String name, int lengthMinutes) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/api/company/job-types/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'lengthMinutes': lengthMinutes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update job type');
    }
    final data = jsonDecode(response.body);
    return JobType.fromJson(data['jobType']);
  }

  static Future<void> deleteJobType(String id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/company/job-types/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete job type');
    }
  }
    
  static Future<List<Client>> getClients() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/clients'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch clients');
    }
    final data = jsonDecode(response.body);
    return (data['clients'] as List)
        .map((c) => Client.fromJson(c))
        .toList();
  }

  static Future<Client> addClient({
    required String name,
    required String houseNumber,
    required String addressLine1,
    required String postcode,
    required String phone,
    required String email,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/clients'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'houseNumber': houseNumber,
        'addressLine1': addressLine1,
        'postcode': postcode,
        'phone': phone,
        'email': email,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to add client');
    }
    final data = jsonDecode(response.body);
    return Client.fromJson(data['client']);
  }

   static Future<Client> updateClient({
    required String id,
    required String name,
    required String houseNumber,
    required String addressLine1,
    required String postcode,
    required String phone,
    required String email,
  }) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/api/clients/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'houseNumber': houseNumber,
        'addressLine1': addressLine1,
        'postcode': postcode,
        'phone': phone,
        'email': email,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update client');
    }
    final data = jsonDecode(response.body);
    return Client.fromJson(data['client']);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
 
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/change-password'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
 
    if (response.statusCode == 200) return;
 
    String? field;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      field = data['field'] as String?;
    } catch (_) {}
 
    throw ChangePasswordException(
      statusCode: response.statusCode,
      message: _errorFrom(response, 'Failed to change password'),
      field: field,
    );
  }

  static Future<void> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
 
    if (response.statusCode == 200) return;
 
    throw ApiException(
      statusCode: response.statusCode,
      message: _errorFrom(response, 'Failed to send the reset link'),
    );
  }
  
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

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