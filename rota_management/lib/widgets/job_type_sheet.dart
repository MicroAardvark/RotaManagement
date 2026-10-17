import 'package:flutter/material.dart';
import '../models/job_type_model.dart';
import '../services/api_service.dart';

/// "1 h 30 min" rather than "90".
String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// Opens the add/edit job type sheet. Pass [jobType] to edit it.
/// Returns true if something was saved.
Future<bool?> showJobTypeSheet(BuildContext context, {JobType? jobType}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => JobTypeSheet(jobType: jobType),
  );
}

class JobTypeSheet extends StatefulWidget {
  final JobType? jobType;

  const JobTypeSheet({super.key, this.jobType});

  @override
  State<JobTypeSheet> createState() => _JobTypeSheetState();
}

class _JobTypeSheetState extends State<JobTypeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _hours;
  late final TextEditingController _minutes;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.jobType != null;

  @override
  void initState() {
    super.initState();
    final length = widget.jobType?.lengthMinutes;
    _name = TextEditingController(text: widget.jobType?.name ?? '');
    _hours = TextEditingController(text: length == null ? '' : '${length ~/ 60}');
    _minutes = TextEditingController(text: length == null ? '' : '${length % 60}');
  }

  @override
  void dispose() {
    _name.dispose();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  int get _totalMinutes {
    final h = int.tryParse(_hours.text.trim()) ?? 0;
    final m = int.tryParse(_minutes.text.trim()) ?? 0;
    return h * 60 + m;
  }

  String? _validateNumber(String? value, int max) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // treated as 0
    final n = int.tryParse(v);
    if (n == null || n < 0 || n > max) return '0-$max';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    if (_totalMinutes < 1) {
      setState(() => _errorMessage = 'Set how long the job takes');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final name = _name.text.trim();
      final existing = widget.jobType;
      if (existing != null) {
        await ApiService.updateJobType(existing.id, name, _totalMinutes);
      } else {
        await ApiService.addJobType(name, _totalMinutes);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : 'Failed to save. Please try again.';
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'Edit job type' : 'Add job type',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Deep clean',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hours,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Hours'),
                      validator: (v) => _validateNumber(v, 24),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minutes'),
                      validator: (v) => _validateNumber(v, 59),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (_totalMinutes > 0) ...[
                const SizedBox(height: 8),
                Text('Shifts of this type last ${formatMinutes(_totalMinutes)}.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Save changes' : 'Add job type'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
