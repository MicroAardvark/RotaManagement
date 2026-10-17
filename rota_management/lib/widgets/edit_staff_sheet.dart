import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/staff_details.dart';
import '../services/api_service.dart';

const int _maxUploadBytes = 5 * 1024 * 1024;
final RegExp _phonePattern = RegExp(r'^\+?[0-9 ()-]{10,20}$');
// HMRC format; matches the server's check in utils/staffDetails.js
final RegExp _niPattern =
    RegExp(r'^(?!BG|GB|NK|KN|TN|NT|ZZ)[A-CEGHJ-PR-TW-Z][A-CEGHJ-NPR-TW-Z]\d{6}[A-D]$');
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Opens the add/edit staff sheet. Pass [staffId] to edit someone;
/// omit it to add a new person (who is emailed an invite). Returns true
/// if anything was saved, so the caller knows to refresh.
Future<bool?> showEditStaffSheet(BuildContext context, {String? staffId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Stops the long form stretching edge to edge on a desktop browser
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
  final _phone = TextEditingController();
  final _houseNumber = TextEditingController();
  final _addressLine1 = TextEditingController();
  final _town = TextEditingController();
  final _postcode = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyRelationship = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _niNumber = TextEditingController();

  String _role = 'employee';
  String? _rtwCheckType;
  DateTime? _followUpDue;
  PlatformFile? _rtwProof;
  PlatformFile? _niProof;

  List<RtwType> _rtwTypes = [];
  StaffRecord? _existing;

  bool _isLoading = true;
  String? _loadError;
  bool _isSaving = false;
  bool _isResending = false;
  String? _errorMessage;

  /// Errors from the server, keyed by field path (e.g. 'address.postcode').
  Map<String, String> _serverErrors = {};

  bool get _isEditing => widget.staffId != null;

  RtwType? get _selectedRtw {
    for (final type in _rtwTypes) {
      if (type.value == _rtwCheckType) return type;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _houseNumber, _addressLine1, _town, _postcode,
      _emergencyName, _emergencyRelationship, _emergencyPhone, _niNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final types = await ApiService.getRtwTypes();
      StaffRecord? existing;
      if (_isEditing) existing = await ApiService.getStaffDetails(widget.staffId!);
      if (!mounted) return;

      setState(() {
        _rtwTypes = types;
        if (existing != null) _fillFrom(existing);
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

  /// Pre-fills the form. Records from before these fields existed just
  /// leave the new fields empty, and validation asks for them on save.
  void _fillFrom(StaffRecord r) {
    _existing = r;
    _name.text = r.name;
    _email.text = r.email;
    _role = r.role == 'manager' ? 'manager' : 'employee';
    _phone.text = r.phone;
    _houseNumber.text = r.houseNumber;
    _addressLine1.text = r.addressLine1;
    _town.text = r.town;
    _postcode.text = r.postcode;
    _emergencyName.text = r.emergencyName;
    _emergencyRelationship.text = r.emergencyRelationship;
    _emergencyPhone.text = r.emergencyPhone;
    _niNumber.text = r.niNumber;
    // Only keep a saved check type the dropdown actually offers
    _rtwCheckType = _rtwTypes.any((t) => t.value == r.rtwCheckType) ? r.rtwCheckType : null;
    _followUpDue = r.rtwFollowUpDue;
  }

  // ---- Validators (mirror the server's rules) ----

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    return _phonePattern.hasMatch(v) ? null : 'Enter a valid phone number';
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    return _emailPattern.hasMatch(v) ? null : 'Enter a valid email address';
  }

  String _normaliseNi(String value) => value.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  String? _validateNi(String? value) {
    final v = _normaliseNi(value ?? '');
    if (v.isEmpty) return 'Required';
    return _niPattern.hasMatch(v) ? null : 'Enter a valid NI number, e.g. AB 12 34 56 C';
  }

  // ---- Files ----

  Future<PlatformFile?> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true, // web has no file path, only the bytes
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;

    if (file.bytes == null) {
      _showSnack("Couldn't read that file. Try another.");
      return null;
    }
    if (file.size > _maxUploadBytes) {
      _showSnack('${file.name} is over 5 MB. Choose a smaller file.');
      return null;
    }
    return file;
  }

  Future<void> _openDocument(String documentId) async {
    final opened = await launchUrl(
      Uri.parse(ApiService.documentUrl(documentId)),
      webOnlyWindowName: '_blank',
    );
    if (!opened) _showSnack("Couldn't open the document.");
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickFollowUpDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDue ?? DateTime(today.year, today.month + 6, today.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 10, today.month, today.day),
      helpText: 'Follow-up right to work check due',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _followUpDue = picked;
      _serverErrors.remove('rightToWork.followUpDue');
    });
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

    final formOk = _formKey.currentState!.validate();
    final rtw = _selectedRtw;
    final needsDate = rtw != null && rtw.timeLimited && _followUpDue == null;
    if (needsDate) {
      setState(() => _serverErrors['rightToWork.followUpDue'] =
          'Time-limited permission needs a follow-up date');
    }
    if (!formOk || needsDate) {
      setState(() => _errorMessage = 'Check the highlighted fields.');
      return;
    }

    final input = StaffInput(
      name: _name.text.trim(),
      email: _email.text.trim(),
      role: _role,
      phone: _phone.text.trim(),
      houseNumber: _houseNumber.text.trim(),
      addressLine1: _addressLine1.text.trim(),
      town: _town.text.trim(),
      postcode: _postcode.text.trim().toUpperCase(),
      emergencyName: _emergencyName.text.trim(),
      emergencyRelationship: _emergencyRelationship.text.trim(),
      emergencyPhone: _emergencyPhone.text.trim(),
      rtwCheckType: _rtwCheckType ?? '',
      rtwFollowUpDue: (rtw?.timeLimited ?? false) ? _followUpDue : null,
      niNumber: _normaliseNi(_niNumber.text),
    );

    setState(() => _isSaving = true);

    try {
      final String id;
      if (_isEditing) {
        id = widget.staffId!;
        await ApiService.updateStaff(id, input);
      } else {
        id = await ApiService.createEmployee(input);
      }

      // Files upload after the record saves, because they need its id.
      final failed = <String>[];
      final rtwProof = _rtwProof;
      if (rtwProof != null) {
        try {
          await ApiService.uploadStaffDocument(id, 'rightToWork', rtwProof.bytes!, rtwProof.name);
        } catch (_) {
          failed.add('right to work proof');
        }
      }
      final niProof = _niProof;
      if (niProof != null) {
        try {
          await ApiService.uploadStaffDocument(id, 'niProof', niProof.bytes!, niProof.name);
        } catch (_) {
          failed.add('NI proof');
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);

      final String message;
      if (failed.isNotEmpty) {
        message = "Saved, but the ${failed.join(' and ')} didn't upload. "
            'Open their record to try again.';
      } else if (_isEditing) {
        message = 'Changes saved';
      } else {
        message = 'Invite sent to ${input.email}';
      }
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
    final rtw = _selectedRtw;

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

            _section(context, 'Basics'),
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

            _section(context, 'Contact'),
            _field(_phone, 'Phone number', 'phone',
                validator: _validatePhone, keyboard: TextInputType.phone),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: _field(_houseNumber, 'House no.', 'address.houseNumber', validator: _required),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _field(_addressLine1, 'Address line 1', 'address.addressLine1',
                      validator: _required, caps: TextCapitalization.words),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _field(_town, 'Town (optional)', 'address.town', caps: TextCapitalization.words),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _field(_postcode, 'Postcode', 'address.postcode',
                      validator: _required, caps: TextCapitalization.characters),
                ),
              ],
            ),

            _section(context, 'Emergency contact'),
            _field(_emergencyName, 'Name', 'emergencyContact.name',
                validator: _required, caps: TextCapitalization.words),
            _field(_emergencyRelationship, 'Relationship', 'emergencyContact.relationship',
                validator: _required, caps: TextCapitalization.sentences),
            _field(_emergencyPhone, 'Phone number', 'emergencyContact.phone',
                validator: _validatePhone, keyboard: TextInputType.phone),

            _section(context, 'Right to work'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _rtwCheckType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'How it was checked',
                  errorText: _serverErrors['rightToWork.checkType'],
                ),
                items: _rtwTypes
                    .map((t) => DropdownMenuItem<String>(
                          value: t.value,
                          child: Text(t.label, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                validator: (value) => value == null ? 'Choose how it was checked' : null,
                onChanged: (value) => setState(() {
                  _rtwCheckType = value;
                  _serverErrors.remove('rightToWork.checkType');
                }),
              ),
            ),
            if (rtw != null && rtw.timeLimited)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: _pickFollowUpDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Follow-up check due',
                      helperText: 'Time-limited permission: check again before it ends.',
                      errorText: _serverErrors['rightToWork.followUpDue'],
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _followUpDue == null
                          ? 'Choose a date'
                          : DateFormat('d MMMM yyyy').format(_followUpDue!),
                    ),
                  ),
                ),
              ),
            _proofRow(
              context,
              label: 'Proof',
              picked: _rtwProof,
              existing: existing == null ? null : existing.documentById(existing.rtwProofDocumentId),
              onPicked: (file) => setState(() => _rtwProof = file),
              hint: rtw?.value == 'share_code'
                  ? 'Upload the PDF of the online check result, not the share code.'
                  : null,
            ),

            _section(context, 'National Insurance'),
            _field(_niNumber, 'NI number', 'niNumber',
                validator: _validateNi, caps: TextCapitalization.characters),
            _proofRow(
              context,
              label: 'Proof',
              picked: _niProof,
              existing: existing == null ? null : existing.documentById(existing.niProofDocumentId),
              onPicked: (file) => setState(() => _niProof = file),
            ),

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

  Widget _section(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
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

  Widget _proofRow(
    BuildContext context, {
    required String label,
    required PlatformFile? picked,
    required StaffDocument? existing,
    required ValueChanged<PlatformFile> onPicked,
    String? hint,
  }) {
    final theme = Theme.of(context);
    final String status;
    if (picked != null) {
      status = 'Will upload: ${picked.name}';
    } else if (existing != null) {
      final when = existing.uploadedAt;
      status = when == null ? 'On file' : 'On file, uploaded ${DateFormat('d MMM yyyy').format(when)}';
    } else {
      status = 'No file yet. JPG, PNG or PDF, up to 5 MB.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.attach_file, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text(status, style: theme.textTheme.bodySmall),
                if (hint != null)
                  Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
          if (existing != null && picked == null)
            TextButton(
              onPressed: () => _openDocument(existing.id),
              child: const Text('View'),
            ),
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    final file = await _pickFile();
                    if (file != null) onPicked(file);
                  },
            child: Text(picked != null || existing != null ? 'Replace' : 'Choose file'),
          ),
        ],
      ),
    );
  }
}
