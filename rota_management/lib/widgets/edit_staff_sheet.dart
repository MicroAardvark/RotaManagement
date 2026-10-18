import 'package:flutter/material.dart';

import '../models/staff_details.dart';
import '../services/api_service.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Opens the add/edit staff sheet. Pass [staffId] to edit someone;
/// omit it to add a new person (who is emailed an invite). Returns true
/// if anything was saved, so the caller knows to refresh.
Future<bool?> showEditStaffSheet(BuildContext context, {String? staffId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Stops the form stretching edge to edge on a desktop browser
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => EditStaffSheet(staffId: staffId),
  );
}

class EditStaffSheet extends StatefulWidget {
  final String? staffId;

  const EditStaffSheet({super.key, this.staffId});

  @override
  State<EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<EditStaffSheet> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();

  String _role = 'employee';
  StaffRecord? _existing;

  bool _isLoading = true;
  String? _loadError;
  bool _isSaving = false;
  bool _isResending = false;
  String? _errorMessage;

  /// Errors from the server, keyed by field name (e.g. 'email').
  Map<String, String> _serverErrors = {};

  bool get _isEditing => widget.staffId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_isEditing) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final existing = await ApiService.getStaffDetails(widget.staffId!);
      if (!mounted) return;

      setState(() {
        _fillFrom(existing);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is ApiException ? e.message : 'Failed to load. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Pre-fills the form.
  void _fillFrom(StaffRecord r) {
    _existing = r;
    _name.text = r.name;
    _email.text = r.email;
    _role = r.role == 'manager' ? 'manager' : 'employee';
  }

  // ---- Validators (match the server's rules) ----

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    return _emailPattern.hasMatch(v) ? null : 'Enter a valid email address';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resendInvite() async {
    final id = widget.staffId;
    if (id == null) return;
    setState(() => _isResending = true);
    try {
      await ApiService.resendInvite(id);
      _showSnack('Invite sent to ${_email.text.trim()}');
    } catch (e) {
      _showSnack(e is ApiException ? e.message : 'Failed to resend the invite');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ---- Save ----

  Future<void> _submit() async {
    setState(() {
      _serverErrors = {};
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Check the highlighted fields.');
      return;
    }

    final input = StaffInput(
      name: _name.text.trim(),
      email: _email.text.trim(),
      role: _role,
    );

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await ApiService.updateStaff(widget.staffId!, input);
      } else {
        await ApiService.createEmployee(input);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);

      final message = _isEditing ? 'Changes saved' : 'Invite sent to ${input.email}';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = Map<String, String>.of(e.fields);
        _errorMessage = e.fields.isEmpty ? e.message : 'Check the highlighted fields.';
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Check your connection and try again.';
        _isSaving = false;
      });
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final existing = _existing;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? 'Edit staff member' : 'Add staff member',
                style: theme.textTheme.titleLarge),
            if (existing != null && !existing.passwordSet) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.mail_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("They haven't set their password yet.")),
                  TextButton(
                    onPressed: _isResending ? null : _resendInvite,
                    child: Text(_isResending ? 'Sending…' : 'Resend invite'),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            _field(_name, 'Full name', 'name',
                validator: _required, caps: TextCapitalization.words),
            _field(_email, 'Email address', 'email',
                validator: _isEditing ? null : _validateEmail,
                keyboard: TextInputType.emailAddress,
                enabled: !_isEditing,
                helper: _isEditing
                    ? 'This is their login, so it can\'t be changed here.'
                    : "We'll email them a link to set their own password."),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'employee', label: Text('Employee'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(value: 'manager', label: Text('Manager'), icon: Icon(Icons.manage_accounts_outlined)),
                ],
                selected: {_role},
                onSelectionChanged: (selection) => setState(() => _role = selection.first),
              ),
            ),
            if (_serverErrors['role'] != null) _errorLine(context, _serverErrors['role']!),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              _errorLine(context, _errorMessage!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save changes' : 'Add and send invite'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorLine(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    bool enabled = true,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboard,
        textCapitalization: caps,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          errorText: _serverErrors[key],
          errorMaxLines: 2,
        ),
        validator: validator,
        onChanged: (_) {
          if (_serverErrors.containsKey(key)) {
            setState(() {
              _serverErrors.remove(key);
            });
          }
        },
      ),
    );
  }
}
