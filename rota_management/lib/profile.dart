import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';
import 'services/session_store.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/staff_avatar.dart';

/// Your own profile, opened from the avatar in the top bar. Built as a
/// list of sections so more can be added underneath.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.getMe(); // fills SessionStore, which this page listens to
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load your profile. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _changePhoto() async {
    // Shrinks the image in the browser before upload; the server then
    // crops it to 256x256. Keeps uploads small enough for nginx's limit.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await picked.readAsBytes();
      await ApiService.uploadProfilePhoto(bytes, picked.name);
      await ApiService.getMe(); // the top bar updates from SessionStore
      _snack('Photo updated');
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Failed to update photo');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.removeProfilePhoto();
      await ApiService.getMe();
      _snack('Photo removed');
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Failed to remove photo');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(activeItem: 'Profile'),
      body: ListenableBuilder(
        listenable: SessionStore.instance,
        builder: (context, _) => _buildBody(context, SessionStore.instance.user),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CurrentUser? user) {
    if (_isLoading && user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null || user == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage ?? 'Unable to load your profile.'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: StaffAvatar(
                id: user.id,
                name: user.name,
                photoVersion: user.photoVersion,
                radius: 48,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isSaving ? null : _changePhoto,
                  icon: _isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(user.photoVersion == null ? 'Add photo' : 'Change photo'),
                ),
                if (user.photoVersion != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isSaving ? null : _removePhoto,
                    child: const Text('Remove'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Text('Your details',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Name'),
              subtitle: Text(user.name),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(user.email),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Role'),
              subtitle: Text(user.isManager ? 'Manager' : 'Employee'),
            ),
            const SizedBox(height: 8),
            Text(
              'To change your name or contact details, ask your manager.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
