import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/change_password_sheet.dart';
import 'widgets/edit_job_types.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openChangePassword(BuildContext context) async {
    final changed = await showChangePasswordSheet(context);
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password changed. We've emailed you to confirm."),
        ),
      );
    }
  }

  Future<void> _confirmLogOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Removes the stored JWT and role from secure storage.
    await ApiService.clearSession();

    if (!context.mounted) return;

    // Clear the whole navigation stack so the back button/gesture can't
    // return to screens that belonged to the logged-out session.
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(activeItem: 'Settings'),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.work_outline),
            title: const Text('Edit Job Types'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showEditJobTypesSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openChangePassword(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Log out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmLogOut(context),
          ),
        ],
      ),
    );
  }
}