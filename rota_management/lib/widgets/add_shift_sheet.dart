import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client_model.dart';
import '../models/employee_model.dart';
import '../models/job_type_model.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';

/// Bottom sheet form for a manager to create a shift for a staff member,
/// or edit an existing one when [existingShift] is passed.
class AddShiftSheet extends StatefulWidget {
  final List<Employee> employees;
  final DateTime initialDay;
  final Employee? initialEmployee;

  /// When set, the sheet edits this shift instead of creating a new one.
  final Shift? existingShift;

  const AddShiftSheet({
    super.key,
    required this.employees,
    required this.initialDay,
    this.initialEmployee,
    this.existingShift,
  });

  @override
  State<AddShiftSheet> createState() => _AddShiftSheetState();
}

class _AddShiftSheetState extends State<AddShiftSheet> {
  Employee? _selectedEmployee;
  late DateTime _shiftDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);

  /// The finish time. Filled in from the job type's length until the
  /// manager picks one themselves ([_endTimeChosen]).
  TimeOfDay? _endTime;
  bool _endTimeChosen = false;
  JobType? _selectedJobType;
  Client? _selectedClient;
  final _notesController = TextEditingController();

  bool _isLoadingJobTypes = true;
  List<JobType> _jobTypes = [];
  String? _jobTypesError;

  bool _isLoadingClients = true;
  List<Client> _clients = [];
  String? _clientsError;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingShift != null;

  @override
  void initState() {
    super.initState();
    _shiftDate = widget.initialDay;
    _selectedEmployee = widget.initialEmployee;

    final existing = widget.existingShift;
    if (existing != null) {
      final start = existing.startTime;
      _shiftDate = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay.fromDateTime(start);
      // Keep the shift's own finish time, which may differ from the job type
      _endTime = TimeOfDay.fromDateTime(existing.endTime);
      _endTimeChosen = true;
      _notesController.text = existing.notes;

      // Null if the employee has since been deactivated; the manager
      // then has to pick someone else before saving.
      final matches = widget.employees.where((e) => e.id == existing.employeeId);
      _selectedEmployee = matches.isNotEmpty ? matches.first : null;
    }

    _loadJobTypes();
    _loadClients();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadJobTypes() async {
    setState(() {
      _isLoadingJobTypes = true;
      _jobTypesError = null;
    });

    try {
      final jobTypes = await ApiService.getJobTypes();
      if (!mounted) return;
      setState(() {
        _jobTypes = jobTypes;
        _isLoadingJobTypes = false;

        // When editing, preselect the shift's current job type. Stays
        // null if that job type has since been deleted.
        final existing = widget.existingShift;
        if (existing != null && _selectedJobType == null) {
          final matches = jobTypes.where((j) => j.id == existing.jobTypeId);
          if (matches.isNotEmpty) _selectedJobType = matches.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _jobTypesError = 'Unable to load job types.';
        _isLoadingJobTypes = false;
      });
    }
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoadingClients = true;
      _clientsError = null;
    });

    try {
      final clients = await ApiService.getClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _isLoadingClients = false;

        // When editing, preselect the shift's current client.
        final existing = widget.existingShift;
        if (existing != null && _selectedClient == null) {
          final matches = clients.where((c) => c.id == existing.clientId);
          if (matches.isNotEmpty) _selectedClient = matches.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _clientsError = 'Unable to load clients.';
        _isLoadingClients = false;
      });
    }
  }

  DateTime _combine(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay _addMinutes(TimeOfDay t, int minutes) {
    final total = (_minutesOf(t) + minutes).clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  /// Fills the finish time from the job type, unless the manager has
  /// already chosen one.
  void _applyJobTypeLength() {
    final jobType = _selectedJobType;
    if (jobType == null || _endTimeChosen) return;
    _endTime = _addMinutes(_startTime, jobType.lengthMinutes);
  }

  /// Shift length in minutes, or null when the finish isn't after the start.
  int? get _durationMinutes {
    final end = _endTime;
    if (end == null) return null;
    final minutes = _minutesOf(end) - _minutesOf(_startTime);
    return minutes > 0 ? minutes : null;
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final oneYearAhead = DateTime(today.year + 1, today.month, today.day);

    // The picker requires firstDate <= initialDate <= lastDate, so widen
    // the range if the shift's date falls outside the normal window
    // (e.g. a past day chosen on the calendar, or editing an old shift).
    final firstDate = _shiftDate.isBefore(yesterday) ? _shiftDate : yesterday;
    final lastDate = _shiftDate.isAfter(oneYearAhead) ? _shiftDate : oneYearAhead;

    final picked = await showDatePicker(
      context: context,
      initialDate: _shiftDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() => _shiftDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked == null) return;
    setState(() {
      // Moving the start keeps the shift the same length
      final length = _durationMinutes;
      _startTime = picked;
      if (_endTimeChosen && length != null) {
        _endTime = _addMinutes(picked, length);
      } else {
        _applyJobTypeLength();
      }
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _addMinutes(_startTime, 60),
      helpText: 'Finish time',
    );
    if (picked == null) return;
    setState(() {
      _endTime = picked;
      _endTimeChosen = true;
    });
  }

  void _resetEndTimeToJobType() {
    setState(() {
      _endTimeChosen = false;
      _applyJobTypeLength();
    });
  }

  Future<void> _submit() async {
    if (_selectedEmployee == null) {
      setState(() => _errorMessage = 'Please select an employee');
      return;
    }
    if (_selectedJobType == null) {
      setState(() => _errorMessage = 'Please select a job type');
      return;
    }
    if (_selectedClient == null) {
      setState(() => _errorMessage = 'Please select a client');
      return;
    }
    if (_endTime == null) {
      setState(() => _errorMessage = 'Please set a finish time');
      return;
    }
    if (_durationMinutes == null) {
      setState(() => _errorMessage = 'The finish time must be after the start time');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final start = _combine(_shiftDate, _startTime);
      final end = _combine(_shiftDate, _endTime!);
      final existing = widget.existingShift;

      if (existing == null) {
        await ApiService.createShift(
          employeeId: _selectedEmployee!.id,
          startTime: start,
          endTime: end,
          jobTypeId: _selectedJobType!.id,
          clientId: _selectedClient!.id,
          notes: _notesController.text.trim(),
        );
      } else {
        await ApiService.updateShift(
          id: existing.id,
          employeeId: _selectedEmployee!.id,
          startTime: start,
          endTime: end,
          jobTypeId: _selectedJobType!.id,
          clientId: _selectedClient!.id,
          notes: _notesController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Show the server's reason when there is one (e.g. "Employee not
        // found in your company"), otherwise a generic message.
        _errorMessage = e is ApiException
            ? e.message
            : _isEditing
                ? 'Failed to save changes. Please try again.'
                : 'Failed to create shift. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final endTime = _endTime;
    final duration = _durationMinutes;
    final jobType = _selectedJobType;
    final differsFromJobType =
        jobType != null && duration != null && duration != jobType.lengthMinutes;

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
            Text(
              _isEditing ? 'Edit shift' : 'Add shift',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            _buildClientField(),
            const SizedBox(height: 12),
            _buildJobTypeField(),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('EEEE d MMMM yyyy').format(_shiftDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start time'),
              subtitle: Text(_startTime.format(context)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: _pickStartTime,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Finish time'),
              subtitle: Text(
                endTime == null
                    ? 'Choose a job type or set a time'
                    : duration == null
                        ? '${endTime.format(context)} (must be after the start)'
                        : '${endTime.format(context)} (${_formatDuration(duration)})',
                style: duration == null && endTime != null
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: _pickEndTime,
            ),
            if (differsFromJobType && jobType != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _resetEndTimeToJobType,
                  child: Text('Use ${jobType.name} length (${_formatDuration(jobType.lengthMinutes)})'),
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
                    : Text(_isEditing ? 'Save changes' : 'Create shift'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientField() {
    if (_isLoadingClients) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_clientsError != null) {
      return Row(
        children: [
          Expanded(child: Text(_clientsError!)),
          TextButton(onPressed: _loadClients, child: const Text('Retry')),
        ],
      );
    }

    if (_clients.isEmpty) {
      return Text(
        'No clients set up yet. Add one from Clients before creating a shift.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Autocomplete<Client>(
      displayStringForOption: (client) => client.name,
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return _clients;
        final query = textValue.text.toLowerCase();
        return _clients.where((c) => c.name.toLowerCase().contains(query));
      },
      onSelected: (client) => setState(() => _selectedClient = client),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // Keep the field in sync if a client was pre-set (e.g. when
        // editing, or after a failed submit) without fighting the
        // user's own typing.
        if (_selectedClient != null && controller.text != _selectedClient!.name) {
          controller.text = _selectedClient!.name;
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Client',
            hintText: 'Search clients…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _selectedClient != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      setState(() => _selectedClient = null);
                    },
                  )
                : null,
          ),
          onChanged: (_) {
            // Typing invalidates a previously selected client until a
            // new option is chosen from the list.
            if (_selectedClient != null) {
              setState(() => _selectedClient = null);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option.name),
                    subtitle: option.fullAddress.isNotEmpty ? Text(option.fullAddress) : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobTypeField() {
    if (_isLoadingJobTypes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_jobTypesError != null) {
      return Row(
        children: [
          Expanded(child: Text(_jobTypesError!)),
          TextButton(onPressed: _loadJobTypes, child: const Text('Retry')),
        ],
      );
    }

    if (_jobTypes.isEmpty) {
      return Text(
        'No job types set up yet. Add one from Manage > Job types before creating a shift.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return DropdownButtonFormField<JobType>(
      initialValue: _selectedJobType,
      decoration: const InputDecoration(labelText: 'Job type'),
      items: _jobTypes
          .map((jt) => DropdownMenuItem(
                value: jt,
                child: Text('${jt.name} (${jt.lengthMinutes} min)'),
              ))
          .toList(),
      onChanged: (value) => setState(() {
        _selectedJobType = value;
        _applyJobTypeLength();
      }),
    );
  }
}