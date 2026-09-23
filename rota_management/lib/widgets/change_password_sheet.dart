import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

/// Opens the change-password sheet. Returns true if the password was
/// changed, so the caller can show a confirmation.
Future<bool?> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const ChangePasswordSheet(),
  );
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  static const _minLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSaving = false;
  String? _errorMessage;

  /// Server-side errors shown under a specific field.
  String? _currentServerError;
  String? _newServerError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _currentServerError = null;
      _newServerError = null;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ApiService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ChangePasswordException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.field) {
          case 'currentPassword':
            _currentServerError = e.message;
            break;
          case 'newPassword':
            _newServerError = e.message;
            break;
          default:
            _errorMessage = e.message;
        }
        _isSaving = false;
      });
    } on http.ClientException {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            "Couldn't reach the server. Check your connection and try again.";
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to change password. Please try again.';
        _isSaving = false;
      });
    }
  }

  Widget _visibilityToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(obscured
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined),
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
    );
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change password',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  errorText: _currentServerError,
                  suffixIcon: _visibilityToggle(_obscureCurrent,
                      () => setState(() => _obscureCurrent = !_obscureCurrent)),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your current password'
                    : null,
                onChanged: (_) {
                  if (_currentServerError != null) {
                    setState(() => _currentServerError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least $_minLength characters.',
                  errorText: _newServerError,
                  errorMaxLines: 2,
                  suffixIcon: _visibilityToggle(_obscureNew,
                      () => setState(() => _obscureNew = !_obscureNew)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a new password';
                  }
                  if (value.length < _minLength) {
                    return 'Password must be at least $_minLength characters';
                  }
                  if (value == _currentController.text) {
                    return 'New password must be different from your current one';
                  }
                  return null;
                },
                onChanged: (_) {
                  if (_newServerError != null) {
                    setState(() => _newServerError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  suffixIcon: _visibilityToggle(_obscureConfirm,
                      () => setState(() => _obscureConfirm = !_obscureConfirm)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your new password';
                  }
                  if (value != _newController.text) {
                    return "Passwords don't match";
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _isSaving ? null : _submit(),
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
                      : const Text('Change password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}