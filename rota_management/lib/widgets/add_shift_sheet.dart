import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client_model.dart';
import '../models/employee_model.dart';
import '../models/job_type_model.dart';
import '../services/api_service.dart';

/// Bottom sheet form for a manager to create a shift for a staff member.
class AddShiftSheet extends StatefulWidget {
  final List<Employee> employees;
  final DateTime initialDay;
  final Employee? initialEmployee;

  const AddShiftSheet({
    super.key,
    required this.employees,
    required this.initialDay,
    this.initialEmployee,
  });

  @override
  State<AddShiftSheet> createState() => _AddShiftSheetState();
}

class _AddShiftSheetState extends State<AddShiftSheet> {
  Employee? _selectedEmployee;
  late DateTime _shiftDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
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

  @override
  void initState() {
    super.initState();
    _shiftDate = widget.initialDay;
    _selectedEmployee = widget.initialEmployee;
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

  DateTime? get _calculatedEndTime {
    if (_selectedJobType == null) return null;
    final start = _combine(_shiftDate, _startTime);
    return start.add(Duration(minutes: _selectedJobType!.lengthMinutes));
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

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ApiService.createShift(
        employeeId: _selectedEmployee!.id,
        startTime: _combine(_shiftDate, _startTime),
        jobTypeId: _selectedJobType!.id,
        clientId: _selectedClient!.id,
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
    final endTime = _calculatedEndTime;

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
            if (endTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ends at ${DateFormat('HH:mm').format(endTime)} '
                  '(${_selectedJobType!.name}, ${_selectedJobType!.lengthMinutes} min)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
        // Keep the field in sync if a client was pre-set (e.g. after a
        // failed submit) without fighting the user's own typing.
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
        'No job types set up yet. Add one from Settings before creating a shift.',
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
      onChanged: (value) => setState(() => _selectedJobType = value),
    );
  }
}