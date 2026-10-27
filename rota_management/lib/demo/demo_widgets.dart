import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'demo_seed.dart';

/// A strip across the top of every page in the demo build, so nobody
/// mistakes it for the live app.
class DemoBanner extends StatelessWidget {
  final Widget child;

  const DemoBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.tertiaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, size: 18, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo with made-up data. Nothing is saved, and refreshing the page starts again.',
                      style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // The banner already handles the top inset (notch, status bar)
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}

/// "Try it as a manager / employee" buttons that log straight in to one
/// of the demo accounts, so visitors don't need to type anything.
class DemoLoginPanel extends StatefulWidget {
  const DemoLoginPanel({super.key});

  @override
  State<DemoLoginPanel> createState() => _DemoLoginPanelState();
}

class _DemoLoginPanelState extends State<DemoLoginPanel> {
  String? _loggingInAs;
  String? _error;

  Future<void> _logIn(String email) async {
    setState(() {
      _loggingInAs = email;
      _error = null;
    });
    try {
      await ApiService.login(email: email, password: DemoSeed.password);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loggingInAs = null);
    }
  }

  Widget _option({
    required String email,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final busy = _loggingInAs != null;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: _loggingInAs == email
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward),
        enabled: !busy,
        onTap: busy ? null : () => _logIn(email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Try the demo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Pick a view to explore. Everything here is made up.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        _option(
          email: DemoSeed.managerEmail,
          icon: Icons.manage_accounts_outlined,
          title: 'Manager view',
          subtitle: 'Build and publish the rota, manage staff, clients and job types',
        ),
        _option(
          email: DemoSeed.employeeEmail,
          icon: Icons.person_outline,
          title: 'Employee view',
          subtitle: 'See your next shift and your own rota',
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 8),
        Text(
          'Or log in with ${DemoSeed.managerEmail} / ${DemoSeed.password}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
