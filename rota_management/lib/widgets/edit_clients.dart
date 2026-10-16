import 'package:flutter/material.dart';
import '../models/client_model.dart';
import '../services/api_service.dart';

/// Opens the add/edit client sheet. Pass an existing [client] to edit
/// it, or omit it to create a new one. Returns true if a client was
/// added or updated, so the caller knows to refresh its list.
Future<bool?> showEditClientSheet(BuildContext context, {Client? client}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditClientSheet(client: client),
  );
}

class EditClientSheet extends StatefulWidget {
  final Client? client;

  const EditClientSheet({super.key, this.client});

  @override
  State<EditClientSheet> createState() => _EditClientSheetState();
}

class _EditClientSheetState extends State<EditClientSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _houseNumberController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _postcodeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _accessController;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _houseNumberController = TextEditingController(text: widget.client?.houseNumber ?? '');
    _addressLine1Controller = TextEditingController(text: widget.client?.addressLine1 ?? '');
    _postcodeController = TextEditingController(text: widget.client?.postcode ?? '');
    _phoneController = TextEditingController(text: widget.client?.phone ?? '');
    _emailController = TextEditingController(text: widget.client?.email ?? '');
    _accessController = TextEditingController(text: widget.client?.access ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _houseNumberController.dispose();
    _addressLine1Controller.dispose();
    _postcodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _accessController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final houseNumber = _houseNumberController.text.trim();
    final addressLine1 = _addressLine1Controller.text.trim();
    final postcode = _postcodeController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final access = _accessController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a client name');
      return;
    }
    if (houseNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter a house number');
      return;
    }
    if (addressLine1.isEmpty) {
      setState(() => _errorMessage = 'Please enter an address');
      return;
    }
    if (postcode.isEmpty) {
      setState(() => _errorMessage = 'Please enter a postcode');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter a phone number');
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter an email address');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        await ApiService.updateClient(
          id: widget.client!.id,
          name: name,
          houseNumber: houseNumber,
          addressLine1: addressLine1,
          postcode: postcode,
          phone: phone,
          email: email,
          access: access,
        );
      } else {
        await ApiService.addClient(
          name: name,
          houseNumber: houseNumber,
          addressLine1: addressLine1,
          postcode: postcode,
          phone: phone,
          email: email,
          access: access,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _isEditing
            ? 'Failed to update client. Please try again.'
            : 'Failed to add client. Please try again.';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit client' : 'Add client',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Client name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _houseNumberController,
                    decoration: const InputDecoration(labelText: 'House no.'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _addressLine1Controller,
                    decoration: const InputDecoration(labelText: 'Address line 1'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postcodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Postcode'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accessController,
              keyboardType: TextInputType.multiline,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Access (optional)',
                hintText: 'How staff get in, e.g. key safe by the back door',
                alignLabelWithHint: true,
              ),
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
                    : Text(_isEditing ? 'Save changes' : 'Add client'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}