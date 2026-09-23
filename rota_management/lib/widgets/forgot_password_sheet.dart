import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

/// Opens the forgot-password sheet. Pass [initialEmail] to pre-fill
/// whatever the user already typed on the login screen.
Future<void> showForgotPasswordSheet(BuildContext context, {String? initialEmail}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ForgotPasswordSheet(initialEmail: initialEmail),
  );
}

class ForgotPasswordSheet extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordSheet({super.key, this.initialEmail});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _isSending = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email address';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await ApiService.requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _sent = true;
        _isSending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isSending = false;
      });
    } on http.ClientException {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            "Couldn't reach the server. Check your connection and try again.";
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to send the reset link. Please try again.';
        _isSending = false;
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
        child: _sent ? _buildSent(context) : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Forgot password', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            "Enter the email address you use to log in and we'll send you a link to reset your password.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: _validateEmail,
            onFieldSubmitted: (_) => _isSending ? null : _submit(),
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
              onPressed: _isSending ? null : _submit,
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send reset link'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.mark_email_read_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Check your email', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "If there's a Rota account for ${_emailController.text.trim()}, "
          "we've sent it a link to reset the password. The link expires in 1 hour.",
        ),
        const SizedBox(height: 8),
        Text(
          "Can't see it? Check your spam or junk folder.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to log in'),
          ),
        ),
      ],
    );
  }
}