import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Opens the "Report a bug / request a feature" sheet. Returns true if
/// the report was sent.
Future<bool?> showReportIssueSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Stops the form stretching edge to edge on a desktop browser
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => const ReportIssueSheet(),
  );
}

class ReportIssueSheet extends StatefulWidget {
  const ReportIssueSheet({super.key});

  @override
  State<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<ReportIssueSheet> {
  static const int _maxDetails = 5000;

  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();

  String? _priority;
  bool _isSending = false;
  String? _errorMessage;

  /// Errors from the server, keyed by field ('priority' or 'details').
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _serverErrors = {};
      _errorMessage = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    try {
      await ApiService.sendFeedback(priority: _priority!, details: _details.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = Map<String, String>.of(e.fields);
        _errorMessage = e.fields.isEmpty ? e.message : 'Check the highlighted fields.';
        _isSending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Check your connection and try again.';
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Text('Report a bug / request a feature', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "This is emailed to the app's developer, who may reply to your email address.",
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  errorText: _serverErrors['priority'],
                ),
                items: const [
                  DropdownMenuItem(value: 'high', child: Text('High: stops work or affects everyone')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium: a problem, but there is a workaround')),
                  DropdownMenuItem(value: 'low', child: Text('Low: minor issue or nice to have')),
                ],
                isExpanded: true,
                validator: (value) => value == null ? 'Choose a priority' : null,
                onChanged: (value) => setState(() {
                  _priority = value;
                  _serverErrors.remove('priority');
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 8,
                maxLines: 16,
                maxLength: _maxDetails,
                decoration: InputDecoration(
                  labelText: 'Details',
                  hintText: 'What happened, or what would you like added?\n\n'
                      'For a bug: which screen, what you did, what you expected and what happened instead.',
                  hintMaxLines: 5,
                  alignLabelWithHint: true,
                  errorText: _serverErrors['details'],
                  errorMaxLines: 2,
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Required';
                  if (v.length < 10) return 'Add a bit more detail';
                  return null;
                },
                onChanged: (_) {
                  if (_serverErrors.containsKey('details')) {
                    setState(() => _serverErrors.remove('details'));
                  }
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSending ? null : _submit,
                icon: _isSending
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
