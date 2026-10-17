import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'models/shift_model.dart';
import 'models/employee_model.dart';
import 'services/api_service.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/shift_details_sheet.dart';
import 'widgets/staff_avatar.dart';

class RotaScreen extends StatefulWidget {
  const RotaScreen({super.key});

  @override
  State<RotaScreen> createState() => _RotaScreenState();
}

class _RotaScreenState extends State<RotaScreen> {
  // Timetable bounds — change these to adjust the visible hours/sizing.
  static const int _startHour = 8;
  static const int _endHour = 18;
  static const double _rowHeight = 72;
  static const double _headerHeight = 36;

  bool _isLoading = true;
  String? _errorMessage;

  bool _isManager = false;
  // ignore: unused_field
  List<Shift> _shifts = [];
  List<Employee> _employees = []; // only needed for managers, for the grid rows

  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Shifts grouped by calendar day, for fast lookup by TableCalendar
  Map<DateTime, List<Shift>> _shiftsByDay = {};

  // Kept in lock-step so the fixed name column and the scrollable
  // timeline scroll together vertically.
  final ScrollController _nameVController = ScrollController();
  final ScrollController _gridVController = ScrollController();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _nameVController.addListener(() => _syncScroll(_nameVController, _gridVController));
    _gridVController.addListener(() => _syncScroll(_gridVController, _nameVController));
    _loadRota();
  }

  @override
  void dispose() {
    _nameVController.dispose();
    _gridVController.dispose();
    super.dispose();
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (_isSyncingScroll || !target.hasClients) return;
    _isSyncingScroll = true;
    target.jumpTo(source.offset);
    _isSyncingScroll = false;
  }

  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> _loadRota() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isManager = await ApiService.checkManager();

      final shifts = isManager
          ? await ApiService.getCompanyShifts()
          : await ApiService.getMyShifts();

      List<Employee> employees = [];
      if (isManager) {
        employees = await ApiService.getCurrentEmployees();
      }

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
        _isManager = isManager;
        _shifts = shifts;
        _employees = employees;
        _shiftsByDay = grouped;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(activeItem: 'Rotas', isManager: _isManager),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return RefreshIndicator(
      onRefresh: _loadRota,
      child: Column(
        children: [
          TableCalendar<Shift>(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now().add(const Duration(days: 180)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.week: 'Week',
              CalendarFormat.month: 'Month',
            },
            eventLoader: _shiftsForDay,
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildDayShiftList()),
        ],
      ),
    );
  }

  Widget _buildDayShiftList() {
    final day = _selectedDay ?? DateTime.now();

    if (_isManager) {
      return _buildHourlyTimetable(day);
    }
    return _buildEmployeeDayView(day);
  }

  /// Measures the widest employee name and returns a label column width
  /// that comfortably fits it, including avatar + padding, clamped to
  /// a sensible min/max so it never gets absurdly narrow or wide.
  double _calculateLabelWidth(BuildContext context, List<Employee> employees) {
    const double avatarAndPadding = 14 * 2 + 8 + 16;
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

  /// Manager view: staff listed down the left (fixed column), hours
  /// running along the top, each employee's row showing their shift(s)
  /// as horizontally-positioned blocks. Same grid layout as the edit
  /// screen, but read-only — no add-shift entry points.
  Widget _buildHourlyTimetable(DateTime day) {
    if (_employees.isEmpty) {
      return const Center(child: Text('No employees found for your company'));
    }

    final dayShifts = _shiftsForDay(day);
    final shiftsByEmployee = <String, List<Shift>>{};
    for (final shift in dayShifts) {
      shiftsByEmployee.putIfAbsent(shift.employeeId, () => []).add(shift);
    }

    final totalHours = _endHour - _startHour;
    final bodyHeight = _employees.length * _rowHeight;
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
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _nameVController,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: _employees.map((e) => _buildNameCell(e)).toList(),
                      ),
                    ),
                  ),
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
                  SizedBox(
                    height: bodyHeight,
                    child: SingleChildScrollView(
                      controller: _gridVController,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: _employees
                            .map((e) => _buildEmployeeRow(
                                  e,
                                  shiftsByEmployee[e.id] ?? [],
                                  totalHours,
                                  hourWidth,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
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

  Widget _buildShiftBlock(
    Shift shift,
    double gridWidth,
    double hourWidth,
    Employee employee,
  ) {
    double timeToOffset(DateTime t) =>
        ((t.hour - _startHour) + t.minute / 60) * hourWidth;

    final rawLeft = timeToOffset(shift.startTime);
    final rawRight = timeToOffset(shift.endTime);

    final left = rawLeft.clamp(0.0, gridWidth);
    final right = rawRight.clamp(0.0, gridWidth);
    final width = (right - left).clamp(4.0, gridWidth);

    // Managers see drafts here too; staff never get them from the API.
    final scheme = Theme.of(context).colorScheme;
    final isDraft = !shift.published;

    return Positioned(
      left: left,
      top: 6,
      bottom: 6,
      width: width,
      child: GestureDetector(
        onTap: () => showShiftDetails(context, shift, employee: employee),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDraft ? scheme.surfaceContainerHighest : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
            border: isDraft ? Border.all(color: scheme.primary, width: 1.5) : null,
          ),
          child: Text(
            '${isDraft ? 'DRAFT · ' : ''}${DateFormat('HH:mm').format(shift.startTime)} - '
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

  /// Non-manager view: unchanged - a simple list of the caller's own
  /// shift(s) on the selected day.
  Widget _buildEmployeeDayView(DateTime day) {
    final dayShifts = _shiftsForDay(day);

    if (dayShifts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Center(
            child: Text(
              'No shifts on ${DateFormat('EEEE d MMMM').format(day)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: dayShifts.length,
      itemBuilder: (context, index) {
        final shift = dayShifts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: () => showShiftDetails(context, shift),
            child: ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(shift.role.isNotEmpty ? shift.role : 'Shift'),
              subtitle: Text(
                '${DateFormat('HH:mm').format(shift.startTime)} – '
                '${DateFormat('HH:mm').format(shift.endTime)}\n'
                '${shift.role}\n${shift.clientName}\n'
                '${shift.clientFullAddress.isNotEmpty ? ', ${shift.clientFullAddress}' : ''}',
              ),
            ),
          ),
        );
      },
    );
  }
}