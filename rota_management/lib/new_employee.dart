import 'package:flutter/material.dart';
import 'services/api_service.dart';

/// Form screen allowing a manager to add a new employee to their
/// company. The new starter is emailed a link to set their own
/// password, so the manager never chooses or sees it.
///
/// Only reachable from manager-only navigation - the backend
/// independently re-verifies manager status and company on submit,
/// so this screen being reachable is a UX convenience, not the
/// security boundary.
class NewEmployeeScreen extends StatefulWidget {
  const NewEmployeeScreen({super.key});

  @override
  State<NewEmployeeScreen> createState() => _NewEmployeeScreenState();
}

class _NewEmployeeScreenState extends State<NewEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _role = 'employee';
  bool _isSaving = false;
  String? _errorMessage;

  /// Server-side error shown under the email field (e.g. duplicate email).
  String? _emailServerError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _emailServerError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      await ApiService.createEmployee(
        name: _nameController.text.trim(),
        email: email,
        role: _role,
      );

      if (!mounted) return;
      // Root ScaffoldMessenger outlives this route, so the snackbar
      // stays visible on the screen we pop back to.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to $email')),
      );
      Navigator.of(context).pop(true); // signal success to caller
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 409) {
          _emailServerError = e.message;
        } else {
          _errorMessage = e.message;
        }
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add employee')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    helperText:
                        "We'll email them a link to set their own password.",
                    helperMaxLines: 2,
                    errorText: _emailServerError,
                    errorMaxLines: 2,
                  ),
                  validator: _validateEmail,
                  onChanged: (_) {
                    if (_emailServerError != null) {
                      setState(() => _emailServerError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Access level'),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add and send invite'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}