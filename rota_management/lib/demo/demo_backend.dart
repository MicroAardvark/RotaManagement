import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'demo_seed.dart';

/// An in-memory stand-in for the Node/Express API, used by demo builds.
///
/// ApiService sends its requests to [client] instead of the network, so
/// every screen, model and error path runs exactly as it does against
/// the real server. The routes, status codes and JSON shapes mirror
/// routes/*.js on the server, including the draft and publish rules.
///
/// State lives only in memory: refreshing the page starts again.
class DemoBackend {
  DemoBackend({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now {
    final seed = DemoSeed.generate(_clock());
    _staff.addAll(seed.staff);
    _clients.addAll(seed.clients);
    _jobTypes.addAll(seed.jobTypes);
    _shifts.addAll(seed.shifts);
    _weeks.addAll(seed.weeks);
  }

  /// A short pause on every request, so loading states still show.
  final Duration latency;
  final DateTime Function() _clock;

  final List<DemoStaff> _staff = [];
  final List<DemoClient> _clients = [];
  final List<DemoJobType> _jobTypes = [];
  final List<DemoShift> _shifts = [];
  final Map<String, DemoWeek> _weeks = {};

  /// Who is "logged in"; the real server keeps this in a cookie.
  String? _sessionUserId;
  int _nextId = 1000;

  late final http.Client client = MockClient(_handle);

  // ---- Plumbing ----

  Future<http.Response> _handle(http.Request request) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    try {
      return _route(request);
    } on _DemoError catch (e) {
      return _respond(e.status, {
        'error': e.message,
        if (e.fields.isNotEmpty) 'fields': e.fields,
      });
    } catch (_) {
      // e.g. a malformed body: answer like the server would, not with a crash
      return _respond(500, {'error': 'Something went wrong in the demo.'});
    }
  }

  http.Response _respond(int status, Map<String, dynamic> body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  http.Response _ok(Map<String, dynamic> body) => _respond(200, body);

  Map<String, dynamic> _body(http.Request request) {
    try {
      if (request.body.isEmpty) return {};
      final data = jsonDecode(request.body);
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {}; // e.g. a multipart photo upload
    }
  }

  String _newId(String prefix) => '$prefix-${_nextId++}';

  http.Response _route(http.Request request) {
    final segments = request.url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2 || segments.first != 'api') {
      throw _DemoError(404, 'Not found');
    }
    final method = request.method;
    final path = segments.sublist(2);

    switch (segments[1]) {
      case 'auth':
        return _auth(method, path, request);
      case 'employees':
        return _employees(method, path, request);
      case 'shifts':
        return _shiftRoutes(method, path, request);
      case 'company':
        return _company(method, path, request);
      case 'clients':
        return _clientRoutes(method, path, request);
      case 'feedback':
        _requireManager();
        return _ok({'message': 'Thanks, your report has been sent.'});
    }
    throw _DemoError(404, 'Not found');
  }

  // ---- Who is asking ----

  DemoStaff _requireUser() {
    final id = _sessionUserId;
    final user = id == null ? null : _findStaff(id);
    if (user == null || !user.active) {
      _sessionUserId = null;
      throw _DemoError(401, 'Not logged in.');
    }
    return user;
  }

  DemoStaff _requireManager() {
    final user = _requireUser();
    if (user.role != 'manager') throw _DemoError(403, 'Manager access required');
    return user;
  }

  DemoStaff? _findStaff(String id) {
    for (final s in _staff) {
      if (s.id == id) return s;
    }
    return null;
  }

  DemoStaff _activeStaff(String id) {
    final staff = _findStaff(id);
    if (staff == null || !staff.active) throw _DemoError(404, 'Employee not found');
    return staff;
  }

  // ---- Auth ----

  http.Response _auth(String method, List<String> path, http.Request request) {
    final route = '$method ${path.join('/')}';
    switch (route) {
      case 'POST login':
        final body = _body(request);
        final email = (body['email'] as String? ?? '').trim().toLowerCase();
        final password = body['password'] as String? ?? '';
        DemoStaff? user;
        for (final s in _staff) {
          if (s.active && s.passwordSet && s.email == email) user = s;
        }
        if (user == null || password != DemoSeed.password) {
          throw _DemoError(401, 'Incorrect email or password.');
        }
        _sessionUserId = user.id;
        return _ok({'role': user.role, 'name': user.name});

      case 'GET me':
        final me = _requireUser();
        return _ok({
          'id': me.id,
          'name': me.name,
          'email': me.email,
          'role': me.role,
          'isOwner': false,
          'photoVersion': null,
        });

      case 'POST logout':
        _sessionUserId = null;
        return _ok({'message': 'Logged out.'});

      case 'POST change-password':
        _requireUser();
        throw _DemoError(400, "Passwords can't be changed in the demo.");

      case 'POST forgot-password':
        // Same reply as the server, which never says whether the email exists
        return _ok({'message': 'If that email has an account, a reset link is on its way.'});

      case 'POST me/photo':
        _requireUser();
        throw _DemoError(400, 'Photo uploads are turned off in the demo.');

      case 'DELETE me/photo':
        _requireUser();
        return _ok({'photoVersion': null});
    }
    throw _DemoError(404, 'Not found');
  }

  // ---- Staff ----

  Map<String, String> _validateStaff(Map<String, dynamic> body, {required bool requireEmail}) {
    final fields = <String, String>{};
    final name = (body['name'] as String? ?? '').trim();
    final role = body['role'];
    if (name.isEmpty) fields['name'] = 'Name is required';
    if (role != 'manager' && role != 'employee') fields['role'] = 'Choose a role';

    var email = '';
    if (requireEmail) {
      email = (body['email'] as String? ?? '').trim().toLowerCase();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        fields['email'] = 'Enter a valid email address';
      }
    }
    if (fields.isNotEmpty) throw _DemoError(400, 'Check the highlighted fields', fields);
    return {'name': name, 'email': email, 'role': role as String};
  }

  http.Response _employees(String method, List<String> path, http.Request request) {
    // GET /api/employees/check-manager works for anyone logged in
    if (method == 'GET' && path.length == 1 && path[0] == 'check-manager') {
      return _ok({'isManager': _requireUser().role == 'manager'});
    }

    final manager = _requireManager();

    if (path.isEmpty) {
      if (method == 'GET') throw _DemoError(404, 'Not found');
      if (method == 'POST') {
        final input = _validateStaff(_body(request), requireEmail: true);
        if (_staff.any((s) => s.email == input['email'])) {
          const message = 'An account with this email already exists';
          throw _DemoError(409, message, {'email': message});
        }
        final created = DemoStaff(
          id: _newId('staff'),
          name: input['name']!,
          email: input['email']!,
          role: input['role']!,
          passwordSet: false, // they would set it from the invite email
        );
        _staff.add(created);
        return _respond(201, {
          'message': 'Invite sent to ${created.email} (not really: this is the demo)',
          'employee': {
            'id': created.id,
            'name': created.name,
            'email': created.email,
            'role': created.role,
          },
        });
      }
    }

    if (method == 'GET' && path.length == 1 && path[0] == 'current') {
      return _ok({
        'employees': [
          for (final s in _staff.where((s) => s.active))
            {'_id': s.id, 'name': s.name, 'role': s.role, 'photoVersion': null},
        ],
      });
    }

    if (path.isEmpty) throw _DemoError(404, 'Not found');
    final staff = _activeStaff(path[0]);
    final action = path.length > 1 ? path[1] : '';

    switch ('$method $action') {
      case 'GET ':
        return _ok({
          'employee': {
            '_id': staff.id,
            'name': staff.name,
            'email': staff.email,
            'role': staff.role,
            'passwordSet': staff.passwordSet,
            'photoVersion': null,
          },
        });

      case 'PUT ':
        final input = _validateStaff(_body(request), requireEmail: false);
        if (staff.id == manager.id && input['role'] != 'manager') {
          const message = "You can't remove your own manager access";
          throw _DemoError(400, message, {'role': message});
        }
        staff
          ..name = input['name']!
          ..role = input['role']!;
        return _ok({'message': 'Saved'});

      case 'GET photo':
        throw _DemoError(404, 'No photo');

      case 'POST resend-invite':
        if (staff.passwordSet) {
          throw _DemoError(409, 'This employee has already set their password');
        }
        return _ok({'message': 'Invite sent to ${staff.email} (not really: this is the demo)'});

      case 'POST deactivate':
        if (staff.id == manager.id) {
          throw _DemoError(400, "You can't deactivate your own account");
        }
        staff.active = false;
        final now = _clock();
        final before = _shifts.length;
        _shifts.removeWhere((s) => s.employeeId == staff.id && !s.startTime.isBefore(now));
        return _ok({
          'message': '${staff.name} has been deactivated',
          'removedShifts': before - _shifts.length,
        });
    }
    throw _DemoError(404, 'Not found');
  }

  // ---- Shifts ----

  /// Matches HISTORY_MONTHS = 2 on the server.
  DateTime _historyStart() {
    final now = _clock();
    return DateTime(now.year, now.month - 2, now.day);
  }

  Map<String, dynamic> _shiftJson(DemoShift s, {bool withEmployee = false}) {
    DemoClient? client;
    for (final c in _clients) {
      if (c.id == s.clientId) client = c;
    }
    final employee = _findStaff(s.employeeId);
    return {
      '_id': s.id,
      'employeeId': withEmployee && employee != null
          ? {'_id': employee.id, 'name': employee.name, 'role': employee.role}
          : s.employeeId,
      'clientId': client == null
          ? null
          : {
              '_id': client.id,
              'name': client.name,
              'houseNumber': client.houseNumber,
              'addressLine1': client.addressLine1,
              'postcode': client.postcode,
              'access': client.access,
            },
      'jobTypeId': s.jobTypeId,
      'startTime': s.startTime.toUtc().toIso8601String(),
      'endTime': s.endTime.toUtc().toIso8601String(),
      'role': s.role,
      'notes': s.notes,
      'published': s.published,
      'notifyPending': s.notifyPending,
    };
  }

  List<DemoShift> _sorted(Iterable<DemoShift> shifts) =>
      shifts.toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// Same checks as buildShiftFields() on the server.
  void _applyShiftFields(DemoShift? target, Map<String, dynamic> body, void Function(DemoShift) onCreate) {
    final employeeId = body['employeeId'] as String?;
    final jobTypeId = body['jobTypeId'] as String?;
    final clientId = body['clientId'] as String?;
    final start = DateTime.tryParse(body['startTime'] as String? ?? '');
    final end = DateTime.tryParse(body['endTime'] as String? ?? '');

    if (employeeId == null || jobTypeId == null || clientId == null ||
        body['startTime'] == null || body['endTime'] == null) {
      throw _DemoError(400, 'employeeId, startTime, endTime, jobTypeId and clientId are required');
    }
    if (start == null) throw _DemoError(400, 'Invalid shift start time');
    if (end == null) throw _DemoError(400, 'Invalid shift finish time');
    if (!end.isAfter(start)) throw _DemoError(400, 'The finish time must be after the start time');
    if (end.difference(start) > const Duration(hours: 24)) {
      throw _DemoError(400, "A shift can't be longer than 24 hours");
    }

    final employee = _findStaff(employeeId);
    if (employee == null || !employee.active) {
      throw _DemoError(404, 'Employee not found in your company');
    }
    if (!_clients.any((c) => c.id == clientId)) {
      throw _DemoError(404, 'Client not found in your company');
    }
    DemoJobType? jobType;
    for (final t in _jobTypes) {
      if (t.id == jobTypeId) jobType = t;
    }
    if (jobType == null) throw _DemoError(404, 'Job type not found');

    final notesRaw = body['notes'];
    final notes = notesRaw is String ? notesRaw.trim() : '';

    if (target == null) {
      onCreate(DemoShift(
        id: _newId('shift'),
        employeeId: employeeId,
        clientId: clientId,
        jobTypeId: jobTypeId,
        startTime: start.toLocal(),
        endTime: end.toLocal(),
        role: jobType.name,
        notes: notes.length > 1000 ? notes.substring(0, 1000) : notes,
        published: false, // new shifts are drafts until the week is published
        notifyPending: true,
      ));
    } else {
      target
        ..employeeId = employeeId
        ..clientId = clientId
        ..jobTypeId = jobTypeId
        ..startTime = start.toLocal()
        ..endTime = end.toLocal()
        ..role = jobType.name
        ..notes = notes.length > 1000 ? notes.substring(0, 1000) : notes
        ..notifyPending = true;
    }
  }

  /// Reads { start, end } for a week and checks it is one week long
  /// (167 to 169 hours, allowing for clock changes).
  (DateTime, DateTime) _parseWeek(Map<String, dynamic> source) {
    final start = DateTime.tryParse(source['start'] as String? ?? '');
    final end = DateTime.tryParse(source['end'] as String? ?? '');
    if (start == null || end == null) throw _DemoError(400, 'Invalid week');
    final hours = end.difference(start).inMinutes / 60;
    if (hours < 167 || hours > 169) throw _DemoError(400, 'Invalid week');
    return (start, end);
  }

  bool _inRange(DemoShift s, DateTime start, DateTime end) =>
      !s.startTime.isBefore(start) && s.startTime.isBefore(end);

  http.Response _shiftRoutes(String method, List<String> path, http.Request request) {
    final first = path.isEmpty ? '' : path[0];

    if (method == 'GET' && first == 'next') {
      final user = _requireUser();
      final now = _clock();
      final upcoming = _sorted(_shifts.where(
          (s) => s.employeeId == user.id && s.published && s.endTime.isAfter(now)));
      return _ok({'shift': upcoming.isEmpty ? null : _shiftJson(upcoming.first)});
    }

    if (method == 'GET' && first == 'mine') {
      final user = _requireUser();
      final from = _historyStart();
      return _ok({
        'shifts': [
          for (final s in _sorted(_shifts.where((s) =>
              s.employeeId == user.id && s.published && !s.startTime.isBefore(from))))
            _shiftJson(s),
        ],
      });
    }

    if (method == 'GET' && first == 'company') {
      _requireManager();
      final from = _historyStart();
      return _ok({
        'shifts': [
          for (final s in _sorted(_shifts.where((s) => !s.startTime.isBefore(from))))
            _shiftJson(s, withEmployee: true),
        ],
      });
    }

    if (method == 'GET' && first == 'week-status') {
      _requireManager();
      final (start, end) = _parseWeek(request.url.queryParameters);
      final week = _weeks[start.toUtc().toIso8601String()];
      return _ok({
        'pendingShifts': _shifts
            .where((s) => _inRange(s, start, end) && (!s.published || s.notifyPending))
            .length,
        'pendingRemovals': week?.pendingRemovals.length ?? 0,
        'publishedAt': week?.publishedAt?.toUtc().toIso8601String(),
      });
    }

    if (method == 'POST' && first == 'publish') {
      _requireManager();
      final (start, end) = _parseWeek(_body(request));
      final key = start.toUtc().toIso8601String();
      final week = _weeks.putIfAbsent(key, DemoWeek.new);

      final affected = <String>{
        for (final s in _shifts)
          if (_inRange(s, start, end) && (!s.published || s.notifyPending)) s.employeeId,
        ...week.pendingRemovals,
      };
      for (final s in _shifts.where((s) => _inRange(s, start, end))) {
        s
          ..published = true
          ..notifyPending = false;
      }
      week
        ..publishedAt = _clock()
        ..pendingRemovals.clear();

      final emailed = affected.where((id) => _findStaff(id)?.active ?? false).length;
      return _ok({'emailed': emailed, 'failed': 0});
    }

    if (method == 'POST' && path.isEmpty) {
      _requireManager();
      late DemoShift created;
      _applyShiftFields(null, _body(request), (s) => created = s);
      _shifts.add(created);
      return _respond(201, {'shift': _shiftJson(created)});
    }

    if (path.length == 1 && (method == 'PUT' || method == 'DELETE')) {
      _requireManager();
      DemoShift? shift;
      for (final s in _shifts) {
        if (s.id == first) shift = s;
      }
      if (shift == null) throw _DemoError(404, 'Shift not found');

      if (method == 'PUT') {
        _applyShiftFields(shift, _body(request), (_) {});
        return _ok({'shift': _shiftJson(shift)});
      }

      _shifts.remove(shift);
      if (shift.published) {
        // Remember who lost a published shift, so the next publish tells them
        final key = DemoSeed.weekKey(DemoSeed.mondayOf(shift.startTime));
        _weeks.putIfAbsent(key, DemoWeek.new).pendingRemovals.add(shift.employeeId);
      }
      return _ok({'success': true});
    }

    throw _DemoError(404, 'Not found');
  }

  // ---- Job types ----

  http.Response _company(String method, List<String> path, http.Request request) {
    if (path.isEmpty || path[0] != 'job-types') throw _DemoError(404, 'Not found');
    _requireManager();

    Map<String, dynamic> jobJson(DemoJobType t) => {'_id': t.id, 'name': t.name};
    String requireName() {
      final name = (_body(request)['name'] as String? ?? '').trim();
      if (name.isEmpty) throw _DemoError(400, 'name is required');
      return name;
    }

    if (path.length == 1) {
      if (method == 'GET') return _ok({'jobTypes': _jobTypes.map(jobJson).toList()});
      if (method == 'POST') {
        final created = DemoJobType(id: _newId('job'), name: requireName());
        _jobTypes.add(created);
        return _respond(201, {'jobType': jobJson(created)});
      }
      throw _DemoError(404, 'Not found');
    }

    DemoJobType? jobType;
    for (final t in _jobTypes) {
      if (t.id == path[1]) jobType = t;
    }
    if (jobType == null) throw _DemoError(404, 'Job type not found');

    if (method == 'PUT') {
      jobType.name = requireName();
      return _ok({'jobType': jobJson(jobType)});
    }
    if (method == 'DELETE') {
      _jobTypes.remove(jobType);
      return _ok({'success': true});
    }
    throw _DemoError(404, 'Not found');
  }

  // ---- Clients ----

  Map<String, dynamic> _clientJson(DemoClient c) => {
        '_id': c.id,
        'name': c.name,
        'houseNumber': c.houseNumber,
        'addressLine1': c.addressLine1,
        'postcode': c.postcode,
        'phone': c.phone,
        'email': c.email,
        'access': c.access,
      };

  /// Name and address are required; phone, email and access are optional.
  Map<String, String> _validateClient(Map<String, dynamic> body) {
    String field(String key) => (body[key] as String? ?? '').trim();
    for (final key in ['name', 'houseNumber', 'addressLine1', 'postcode']) {
      if (field(key).isEmpty) throw _DemoError(400, '$key is required');
    }
    return {
      for (final key in ['name', 'houseNumber', 'addressLine1', 'postcode', 'phone', 'email', 'access'])
        key: key == 'postcode' ? field(key).toUpperCase() : field(key),
    };
  }

  http.Response _clientRoutes(String method, List<String> path, http.Request request) {
    _requireManager();

    if (path.isEmpty && method == 'GET') {
      final sorted = [..._clients]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return _ok({'clients': sorted.map(_clientJson).toList()});
    }

    if (path.isEmpty && method == 'POST') {
      final v = _validateClient(_body(request));
      final created = DemoClient(
        id: _newId('client'),
        name: v['name']!,
        houseNumber: v['houseNumber']!,
        addressLine1: v['addressLine1']!,
        postcode: v['postcode']!,
        phone: v['phone']!,
        email: v['email']!,
        access: v['access']!,
      );
      _clients.add(created);
      return _respond(201, {'client': _clientJson(created)});
    }

    if (path.length == 1 && method == 'PUT') {
      DemoClient? client;
      for (final c in _clients) {
        if (c.id == path[0]) client = c;
      }
      if (client == null) throw _DemoError(404, 'Client not found');
      final v = _validateClient(_body(request));
      client
        ..name = v['name']!
        ..houseNumber = v['houseNumber']!
        ..addressLine1 = v['addressLine1']!
        ..postcode = v['postcode']!
        ..phone = v['phone']!
        ..email = v['email']!
        ..access = v['access']!;
      return _ok({'client': _clientJson(client)});
    }

    throw _DemoError(404, 'Not found');
  }
}

class _DemoError implements Exception {
  final int status;
  final String message;
  final Map<String, String> fields;

  _DemoError(this.status, this.message, [this.fields = const {}]);
}
