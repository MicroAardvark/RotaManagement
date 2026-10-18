import 'package:flutter/material.dart';
import '../models/job_type_model.dart';
import '../services/api_service.dart';

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

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.jobType != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.jobType?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final name = _name.text.trim();
      final existing = widget.jobType;
      if (existing != null) {
        await ApiService.updateJobType(existing.id, name);
      } else {
        await ApiService.addJobType(name);
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
