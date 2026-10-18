import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'models/shift_model.dart';
import 'models/employee_model.dart';
import 'services/api_service.dart';
import 'widgets/add_shift_sheet.dart';
import 'dart:ui' as ui;
import 'widgets/app_top_bar.dart';
import 'widgets/shift_details_sheet.dart';
import 'widgets/staff_avatar.dart';

class RotaEditScreen extends StatefulWidget {
  const RotaEditScreen({super.key});

  @override
  State<RotaEditScreen> createState() => _RotaEditScreenState();
}

class _RotaEditScreenState extends State<RotaEditScreen> {
  // Timetable bounds — change these to adjust the visible hours/sizing.
  static const int _startHour = 8;
  static const int _endHour = 18;
  static const double _rowHeight = 72;
  static const double _headerHeight = 36;

  bool _isLoading = true;
  bool _isManager = false;
  bool _isAuthorised = true;
  String? _errorMessage;

  // ignore: unused_field
  List<Shift> _shifts = [];
  List<Employee> _employees = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<Shift>> _shiftsByDay = {};

  // Publishing: status of the week shown in the calendar
  WeekStatus? _weekStatus;
  DateTime? _weekStatusFor;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadRota();
  }

  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Measures the widest employee name and returns a label column width
  /// that comfortably fits it, including avatar + padding, clamped to
  /// a sensible min/max so it never gets absurdly narrow or wide.
  double _calculateLabelWidth(BuildContext context, List<Employee> employees) {
    const double avatarAndPadding = 14 * 2 + 8 + 16; // avatar diameter + gap + horizontal padding
    const double minWidth = 110;
    const double maxWidth = 220;

    if (employees.isEmpty) return minWidth;

    final style = Theme.of(context).textTheme.bodyMedium;
    double widest = 0;

    for (final employee in employees) {
      final painter = TextPainter(
        text: TextSpan(text: employee.name, style: style),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }

    return (widest + avatarAndPadding).clamp(minWidth, maxWidth);
  }

  Future<void> _loadRota() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isManager = await ApiService.checkManager();

      if (!isManager) {
        if (!mounted) return;
        setState(() {
          _isManager = false;
          _isAuthorised = false;
          _isLoading = false;
        });
        return;
      }

      final shifts = await ApiService.getCompanyShifts();
      final employees = await ApiService.getCurrentEmployees();

      final grouped = <DateTime, List<Shift>>{};
      for (final shift in shifts) {
        final key = _dayKey(shift.startTime);
        grouped.putIfAbsent(key, () => []).add(shift);
      }
      for (final list in grouped.values) {
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
      }

      if (!mounted) return;
      setState(() {
        _isManager = true;
        _isAuthorised = true;
        _shifts = shifts;
        _employees = employees;
        _shiftsByDay = grouped;
        _isLoading = false;
      });
      _loadWeekStatus(_focusedDay, force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load the rota. Please try again.';
        _isLoading = false;
      });
    }
  }

  List<Shift> _shiftsForDay(DateTime day) {
    return _shiftsByDay[_dayKey(day)] ?? [];
  }

  /// Loads how many changes are waiting to be published for the week
  /// containing [day]. Skips the call if that week is already loaded.
  Future<void> _loadWeekStatus(DateTime day, {bool force = false}) async {
    final monday = ApiService.mondayOf(day);
    if (!force && _weekStatusFor == monday) return;
    _weekStatusFor = monday;
    try {
      final status = await ApiService.getWeekStatus(monday);
      if (!mounted || _weekStatusFor != monday) return;
      setState(() => _weekStatus = status);
    } catch (_) {
      if (!mounted) return;
      setState(() => _weekStatus = null); // the bar falls back to "Publish week"
    }
  }

  Future<void> _publishWeek() async {
    final monday = ApiService.mondayOf(_focusedDay);
    final label = DateFormat('d MMM').format(monday);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Publish w/c $label?'),
        content: const Text(
          'Staff will see this week, and anyone with new, changed or '
          'removed shifts will be emailed their rota.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isPublishing = true);
    try {
      final result = await ApiService.publishWeek(monday);
      if (!mounted) return;
      final emailed = result.emailed == 1 ? '1 person' : '${result.emailed} people';
      final message = result.failed == 0
          ? 'Published. Emailed $emailed.'
          : 'Published. Emailed $emailed, but ${result.failed} email(s) failed. Check their addresses.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _loadRota();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Failed to publish the rota')),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Widget _buildPublishBar() {
    final theme = Theme.of(context);
    final status = _weekStatus;
    final pending = status?.pendingTotal;
    final String text;
    if (pending == null) {
      text = 'Publish to show this week to staff';
    } else if (pending == 0) {
      text = status!.publishedAt == null ? 'Nothing to publish this week' : 'This week is up to date';
    } else {
      text = pending == 1 ? '1 change not published yet' : '$pending changes not published yet';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: (pending ?? 0) > 0 ? theme.colorScheme.secondaryContainer : null,
      child: Row(
        children: [
          Icon(
            (pending ?? 0) > 0 ? Icons.edit_calendar_outlined : Icons.check_circle_outline,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          FilledButton.icon(
            onPressed: _isPublishing || pending == 0 ? null : _publishWeek,
            icon: _isPublishing
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, size: 18),
            label: const Text('Publish week'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(activeItem: 'Rotas', isManager: _isManager),
      body: _buildBody(),
      floatingActionButton: _isAuthorised && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _openAddShiftSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add shift'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAuthorised) {
      return _buildUnauthorised();
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadRota, child: const Text('Retry')),
          ],
        ),
      );
    }

    final day = _selectedDay ?? DateTime.now();

    // One scrolling list for the whole page, so the calendar, publish
    // bar, timetable and every staff row can all be scrolled to, and
    // pull-to-refresh works.
    return RefreshIndicator(
      onRefresh: _loadRota,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Room for the floating "Add shift" button under the last row
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          TableCalendar<Shift>(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now().add(const Duration(days: 180)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            calendarFormat: CalendarFormat.week,
            availableCalendarFormats: const {CalendarFormat.week: 'Week'},
            eventLoader: _shiftsForDay,
            // Vertical drags scroll the page rather than the calendar
            availableGestures: AvailableGestures.horizontalSwipe,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadWeekStatus(focusedDay);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadWeekStatus(focusedDay);
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(shape: BoxShape.circle),
            ),
          ),
          _buildPublishBar(),
          const Divider(height: 1),
          _buildHourlyTimetable(day),
        ],
      ),
    );
  }

  Widget _buildUnauthorised() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Not authorised to access this page',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Editing the rota is only available to managers.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              },
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }

  /// Hourly timetable for the selected day: staff listed down the left
  /// (fixed column), hours running along the top, each employee's row
  /// showing their shift(s) as horizontally-positioned blocks. Hour
  /// column width is calculated from the available screen width so the
  /// grid always fills the space. It's laid out at full height and
  /// scrolls with the rest of the page.
  Widget _buildHourlyTimetable(DateTime day) {
    if (_employees.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text('No employees found for your company')),
      );
    }

    final dayShifts = _shiftsForDay(day);
    final shiftsByEmployee = <String, List<Shift>>{};
    for (final shift in dayShifts) {
      shiftsByEmployee.putIfAbsent(shift.employeeId, () => []).add(shift);
    }

    final totalHours = _endHour - _startHour;
    final labelWidth = _calculateLabelWidth(context, _employees);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - labelWidth;
        final hourWidth = gridWidth / totalHours;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed left column: header spacer + employee name rows
            SizedBox(
              width: labelWidth,
              child: Column(
                children: [
                  Container(
                    height: _headerHeight,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                  ..._employees.map(_buildNameCell),
                ],
              ),
            ),
            // Right side: hour header + employee timeline rows, filling
            // the remaining width — no horizontal scroll needed.
            SizedBox(
              width: gridWidth,
              child: Column(
                children: [
                  _buildHourHeader(totalHours, hourWidth),
                  ..._employees.map((e) => _buildEmployeeRow(
                        e,
                        shiftsByEmployee[e.id] ?? [],
                        totalHours,
                        hourWidth,
                      )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNameCell(Employee employee) {
    return Container(
      height: _rowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          StaffAvatar(
            id: employee.id,
            name: employee.name,
            photoVersion: employee.photoVersion,
            radius: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              employee.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourHeader(int totalHours, double hourWidth) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: List.generate(totalHours, (i) {
          final hour = _startHour + i;
          return Container(
            width: hourWidth,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmployeeRow(
    Employee employee,
    List<Shift> shifts,
    int totalHours,
    double hourWidth,
  ) {
    final gridWidth = totalHours * hourWidth;

    return Container(
      height: _rowHeight,
      width: gridWidth,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Stack(
        children: [
          // Hour grid lines
          Row(
            children: List.generate(
              totalHours,
              (i) => Container(
                width: hourWidth,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade100)),
                ),
              ),
            ),
          ),
          // Shift blocks
          ...shifts.map((shift) => _buildShiftBlock(shift, gridWidth, hourWidth, employee)),
        ],
      ),
    );
  }

  Widget _buildShiftBlock(Shift shift, double gridWidth, double hourWidth, Employee employee) {
    double timeToOffset(DateTime t) =>
        ((t.hour - _startHour) + t.minute / 60) * hourWidth;

    final rawLeft = timeToOffset(shift.startTime);
    final rawRight = timeToOffset(shift.endTime);

    final left = rawLeft.clamp(0.0, gridWidth);
    final right = rawRight.clamp(0.0, gridWidth);
    final width = (right - left).clamp(4.0, gridWidth);

    // Drafts: outlined and pale, so it's clear staff can't see them yet.
    final scheme = Theme.of(context).colorScheme;
    final isDraft = !shift.published;
    final label = isDraft ? 'DRAFT · ' : (shift.notifyPending ? 'CHANGED · ' : '');

    return Positioned(
      left: left,
      top: 6,
      bottom: 6,
      width: width,
      child: GestureDetector(
        onTap: () => _onShiftTapped(shift, employee),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDraft ? scheme.surfaceContainerHighest : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
            border: isDraft || shift.notifyPending
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          child: Text(
            '$label${DateFormat('HH:mm').format(shift.startTime)} - '
            '${DateFormat('HH:mm').format(shift.endTime)}\n'
            '${shift.role}\n'
            '${shift.clientName}\n'
            '${shift.clientFullAddress.isNotEmpty ? ', ${shift.clientFullAddress}' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDraft ? scheme.onSurface : scheme.onPrimaryContainer,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
    );
  }

  Future<void> _onShiftTapped(Shift shift, Employee employee) async {
    final result = await showShiftDetails(
      context,
      shift,
      employee: employee,
      canManage: true,
    );
    if (!mounted) return;

    if (result == ShiftSheetResult.deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift deleted')),
      );
      _loadRota();
    } else if (result == ShiftSheetResult.edit) {
      _openEditShiftSheet(shift);
    }
  }

  Future<void> _openEditShiftSheet(Shift shift) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddShiftSheet(
        employees: _employees,
        initialDay: shift.startTime,
        existingShift: shift,
      ),
    );
    if (saved == true && mounted) _loadRota();
  }

  Future<void> _openAddShiftSheet({Employee? preselectedEmployee, DateTime? day}) async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees found for your company')),
      );
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddShiftSheet(
        employees: _employees,
        initialDay: day ?? _selectedDay ?? DateTime.now(),
        initialEmployee: preselectedEmployee,
      ),
    );

    if (created == true) {
      _loadRota();
    }
  }
}