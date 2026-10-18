import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/session_store.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/change_password_sheet.dart';
import 'widgets/report_issue_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // After a page refresh the user may not be loaded yet; this fills
    // SessionStore, which the list below listens to.
    if (SessionStore.instance.user == null) {
      ApiService.getMe().catchError((_) => null);
    }
  }

  Future<void> _openReportIssue(BuildContext context) async {
    final sent = await showReportIssueSheet(context);
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks, your report has been sent.')),
      );
    }
  }

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

    // Clears the session cookie on the server and the cached user here.
    await ApiService.logout();

    if (!context.mounted) return;

    // Clear the whole navigation stack so the back button/gesture can't
    // return to screens that belonged to the logged-out session.
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final errorColour = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: const AppTopBar(activeItem: 'Settings'),
      body: ListenableBuilder(
        listenable: SessionStore.instance,
        builder: (context, _) {
          final isManager = SessionStore.instance.user?.isManager ?? false;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openChangePassword(context),
              ),
              if (isManager)
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Report a bug / request a feature'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openReportIssue(context),
                ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: errorColour),
                title: Text('Log out', style: TextStyle(color: errorColour)),
                onTap: () => _confirmLogOut(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
