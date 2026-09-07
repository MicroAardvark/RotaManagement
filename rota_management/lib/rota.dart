import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'models/shift_model.dart';
import 'models/employee_model.dart';
import 'services/api_service.dart';

class RotaScreen extends StatefulWidget {
  const RotaScreen({super.key});

  @override
  State<RotaScreen> createState() => _RotaScreenState();
}

class _RotaScreenState extends State<RotaScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  bool _isManager = false;
  List<Shift> _shifts = [];
  List<Employee> _employees = []; // only needed for managers, for the add-shift form

  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Shifts grouped by calendar day, for fast lookup by TableCalendar
  Map<DateTime, List<Shift>> _shiftsByDay = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadRota();
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
      appBar: AppBar(
        title: const Text('Rota'),
        actions: [
          PopupMenuButton<CalendarFormat>(
            icon: const Icon(Icons.view_module_outlined),
            tooltip: 'Calendar view',
            onSelected: (format) => setState(() => _calendarFormat = format),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: CalendarFormat.week,
                child: Text('Week'),
              ),
              PopupMenuItem(
                value: CalendarFormat.month,
                child: Text('Month'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isManager
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
      return _buildManagerDayView(day);
    }
    return _buildEmployeeDayView(day);
  }

  /// Manager view: one row per employee, showing their shift(s) on the
  /// selected day (or "Off" if none). Tapping a row with no shift opens
  /// the add-shift sheet pre-filled for that employee and day.
  Widget _buildManagerDayView(DateTime day) {
    if (_employees.isEmpty) {
      return const Center(child: Text('No employees found for your company'));
    }

    // Group the day's shifts by employeeId for fast lookup per row
    final dayShifts = _shiftsForDay(day);
    final shiftsByEmployee = <String, List<Shift>>{};
    for (final shift in dayShifts) {
      shiftsByEmployee.putIfAbsent(shift.employeeId, () => []).add(shift);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _employees.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final employee = _employees[index];
        final employeeShifts = shiftsByEmployee[employee.id] ?? [];

        return ListTile(
          leading: CircleAvatar(
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
            ),
          ),
          title: Text(employee.name),
          subtitle: Text(employee.role),
          trailing: _buildShiftTrailing(employeeShifts),
          onTap: employeeShifts.isEmpty
              ? () => _openAddShiftSheet(preselectedEmployee: employee, day: day)
              : null,
        );
      },
    );
  }

  /// The right-hand side of a manager's employee row: shift time(s) or
  /// an "Off" chip if the employee has nothing scheduled that day.
  Widget _buildShiftTrailing(List<Shift> shifts) {
    if (shifts.isEmpty) {
      return Chip(
        label: const Text('Off'),
        visualDensity: VisualDensity.compact,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: shifts.map((shift) {
        return Text(
          '${DateFormat('HH:mm').format(shift.startTime)}–'
          '${DateFormat('HH:mm').format(shift.endTime)}'
          '${shift.role.isNotEmpty ? ' (${shift.role})' : ''}',
          style: Theme.of(context).textTheme.bodyMedium,
        );
      }).toList(),
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
          child: ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(shift.role.isNotEmpty ? shift.role : 'Shift'),
            subtitle: Text(
              '${DateFormat('HH:mm').format(shift.startTime)} – '
              '${DateFormat('HH:mm').format(shift.endTime)}',
            ),
          ),
        );
      },
    );
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
      builder: (context) => _AddShiftSheet(
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

/// Bottom sheet form for a manager to create a shift for a staff member.
class _AddShiftSheet extends StatefulWidget {
  final List<Employee> employees;
  final DateTime initialDay;
  final Employee? initialEmployee;

  const _AddShiftSheet({
    required this.employees,
    required this.initialDay,
    this.initialEmployee,
  });

  @override
  State<_AddShiftSheet> createState() => _AddShiftSheetState();
}

class _AddShiftSheetState extends State<_AddShiftSheet> {
  Employee? _selectedEmployee;
  late DateTime _shiftDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final _roleController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _shiftDate = widget.initialDay;
    _selectedEmployee = widget.initialEmployee;
  }

  @override
  void dispose() {
    _roleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _shiftDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _shiftDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedEmployee == null) {
      setState(() => _errorMessage = 'Please select an employee');
      return;
    }

    final start = _combine(_shiftDate, _startTime);
    final end = _combine(_shiftDate, _endTime);

    if (!end.isAfter(start)) {
      setState(() => _errorMessage = 'End time must be after start time');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ApiService.createShift(
        employeeId: _selectedEmployee!.id,
        startTime: start,
        endTime: end,
        role: _roleController.text.trim(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to create shift. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add shift', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<Employee>(
              initialValue: _selectedEmployee,
              decoration: const InputDecoration(labelText: 'Employee'),
              items: widget.employees
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedEmployee = value),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('EEEE d MMMM yyyy').format(_shiftDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(_startTime.format(context)),
                    onTap: _pickStartTime,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    subtitle: Text(_endTime.format(context)),
                    onTap: _pickEndTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role / area (optional)',
                hintText: 'e.g. Till, Kitchen, Floor',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create shift'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}