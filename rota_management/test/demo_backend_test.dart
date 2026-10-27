import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rota_management/demo/demo_backend.dart';
import 'package:rota_management/demo/demo_seed.dart';
import 'package:rota_management/models/client_model.dart';
import 'package:rota_management/models/employee_model.dart';
import 'package:rota_management/models/job_type_model.dart';
import 'package:rota_management/models/shift_model.dart';
import 'package:rota_management/services/session_store.dart';

/// Checks the demo's fake API speaks the same JSON as the real server,
/// by parsing every reply with the app's own models.
void main() {
  // A Tuesday mid-morning, so "this week" has past and future shifts.
  final now = DateTime(2026, 10, 27, 10, 0);
  late DemoBackend backend;
  late http.Client client;

  Uri url(String path, [Map<String, String>? query]) =>
      Uri.parse('http://demo.local$path').replace(queryParameters: query);

  Future<(int, Map<String, dynamic>)> call(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    final request = http.Request(method, url(path, query));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await client.send(request));
    return (response.statusCode, jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> logIn(String email) async {
    final (status, _) = await call('POST', '/api/auth/login',
        body: {'email': email, 'password': DemoSeed.password});
    expect(status, 200);
  }

  Map<String, String> weekOf(DateTime day) {
    final monday = DemoSeed.mondayOf(day);
    final next = DateTime(monday.year, monday.month, monday.day + 7);
    return {
      'start': monday.toUtc().toIso8601String(),
      'end': next.toUtc().toIso8601String(),
    };
  }

  setUp(() {
    backend = DemoBackend(clock: () => now, latency: Duration.zero);
    client = backend.client;
  });

  test('rejects a wrong password and requires a login', () async {
    final (badLogin, _) = await call('POST', '/api/auth/login',
        body: {'email': DemoSeed.managerEmail, 'password': 'nope'});
    expect(badLogin, 401);

    final (me, _) = await call('GET', '/api/auth/me');
    expect(me, 401);
  });

  test('manager sees the whole rota, drafts included', () async {
    await logIn(DemoSeed.managerEmail);

    final (_, meBody) = await call('GET', '/api/auth/me');
    expect(CurrentUser.fromJson(meBody).isManager, isTrue);

    final (status, body) = await call('GET', '/api/shifts/company');
    expect(status, 200);
    final shifts = (body['shifts'] as List).cast<Map<String, dynamic>>().map(Shift.fromJson).toList();
    expect(shifts, isNotEmpty);
    expect(shifts.every((s) => s.employeeName != null && s.clientName.isNotEmpty), isTrue);
    expect(shifts.any((s) => !s.published), isTrue, reason: 'the week after next is in draft');

    final (_, staffBody) = await call('GET', '/api/employees/current');
    final staff = (staffBody['employees'] as List).cast<Map<String, dynamic>>().map(Employee.fromJson);
    expect(staff.length, 6);

    final (_, clientBody) = await call('GET', '/api/clients');
    final clients = (clientBody['clients'] as List).cast<Map<String, dynamic>>().map(Client.fromJson);
    expect(clients.length, 10);

    final (_, jobBody) = await call('GET', '/api/company/job-types');
    final jobTypes = (jobBody['jobTypes'] as List).cast<Map<String, dynamic>>().map(JobType.fromJson);
    expect(jobTypes.length, 5);
  });

  test('employee only sees their own published shifts', () async {
    await logIn(DemoSeed.employeeEmail);

    final (status, body) = await call('GET', '/api/shifts/mine');
    expect(status, 200);
    final shifts = (body['shifts'] as List).cast<Map<String, dynamic>>().map(Shift.fromJson).toList();
    expect(shifts, isNotEmpty);
    expect(shifts.every((s) => s.published && s.employeeId == 'staff-2'), isTrue);

    final (_, next) = await call('GET', '/api/shifts/next');
    expect(next['shift'], isNotNull);

    final (forbidden, _) = await call('GET', '/api/shifts/company');
    expect(forbidden, 403);
  });

  test('a new shift is a draft until its week is published', () async {
    await logIn(DemoSeed.managerEmail);
    final start = DateTime(2026, 10, 30, 18, 0); // Friday this week
    final week = weekOf(start);

    final (_, before) = await call('GET', '/api/shifts/week-status', query: week);
    expect(before['pendingShifts'], 0, reason: 'this week starts fully published');

    final (created, body) = await call('POST', '/api/shifts', body: {
      'employeeId': 'staff-3',
      'startTime': start.toUtc().toIso8601String(),
      'endTime': start.add(const Duration(hours: 2)).toUtc().toIso8601String(),
      'jobTypeId': 'job-4',
      'clientId': 'client-3',
      'notes': 'Extra clean before inspection',
    });
    expect(created, 201);
    final shift = Shift.fromJson(body['shift'] as Map<String, dynamic>);
    expect(shift.published, isFalse);
    expect(shift.clientName, 'Brookside Dental Practice');

    final (_, pending) = await call('GET', '/api/shifts/week-status', query: week);
    expect(pending['pendingShifts'], 1);

    final (published, result) = await call('POST', '/api/shifts/publish', body: week);
    expect(published, 200);
    expect(result['emailed'], 1);

    final (_, after) = await call('GET', '/api/shifts/week-status', query: week);
    expect(after['pendingShifts'], 0);
    expect(after['publishedAt'], isNotNull);
  });

  test('deleting a published shift is queued for the next publish', () async {
    await logIn(DemoSeed.managerEmail);
    final (_, body) = await call('GET', '/api/shifts/company');
    final upcoming = (body['shifts'] as List)
        .cast<Map<String, dynamic>>()
        .map(Shift.fromJson)
        .firstWhere((s) => s.published && s.startTime.isAfter(now));

    final (status, _) = await call('DELETE', '/api/shifts/${upcoming.id}');
    expect(status, 200);

    final (_, week) = await call('GET', '/api/shifts/week-status', query: weekOf(upcoming.startTime));
    expect(week['pendingRemovals'], 1);
  });

  test('rejects a shift that finishes before it starts', () async {
    await logIn(DemoSeed.managerEmail);
    final start = DateTime(2026, 10, 29, 12, 0);
    final (status, body) = await call('POST', '/api/shifts', body: {
      'employeeId': 'staff-2',
      'startTime': start.toUtc().toIso8601String(),
      'endTime': start.subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
      'jobTypeId': 'job-1',
      'clientId': 'client-1',
    });
    expect(status, 400);
    expect(body['error'], 'The finish time must be after the start time');
  });

  test('adding staff with a used email gives a field error', () async {
    await logIn(DemoSeed.managerEmail);
    final (status, body) = await call('POST', '/api/employees',
        body: {'name': 'Someone', 'email': DemoSeed.employeeEmail, 'role': 'employee'});
    expect(status, 409);
    expect((body['fields'] as Map)['email'], isNotNull);
  });
}
