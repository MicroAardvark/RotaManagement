import 'package:flutter/material.dart';
import 'models/employee_model.dart';
import 'services/api_service.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/edit_staff_sheet.dart';
import 'widgets/staff_avatar.dart';

/// Manager-only staff list. "Add staff" opens the add sheet; tapping a
/// person opens the same sheet in edit mode.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Employee> _employees = [];
  bool _isLoading = true;
  bool _isAuthorised = true;
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
      final isManager = await ApiService.checkManager();
      if (!isManager) {
        if (!mounted) return;
        setState(() {
          _isAuthorised = false;
          _isLoading = false;
        });
        return;
      }

      final employees = await ApiService.getCurrentEmployees();
      if (!mounted) return;
      setState(() {
        _isAuthorised = true;
        _employees = employees..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load staff. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSheet({String? staffId}) async {
    final saved = await showEditStaffSheet(context, staffId: staffId);
    if (saved == true && mounted) _load();
  }

  Future<void> _confirmDeactivate(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Deactivate ${employee.name}?'),
        content: const Text(
          "They'll be logged out and won't be able to log in again. "
          'Their upcoming shifts will be removed from the rota. Past shifts are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final removed = await ApiService.deactivateEmployee(employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed == 0
                ? '${employee.name} has been deactivated.'
                : '${employee.name} has been deactivated. '
                    '$removed upcoming shift(s) were removed. Check the rota.',
          ),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Failed to deactivate')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(activeItem: 'Manage', isManager: true),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      floatingActionButton: _isAuthorised && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: () => _openSheet(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add staff'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isAuthorised) {
      return _buildUnauthorised();
    }
    if (_errorMessage != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Text(_errorMessage!),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }
    if (_employees.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No staff yet. Add your first with "Add staff".')),
        ],
      );
    }

    final theme = Theme.of(context);
    return ListView.separated(
      // Room for the floating button over the last row
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _employees.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final employee = _employees[index];
        return ListTile(
          leading: StaffAvatar(
            id: employee.id,
            name: employee.name,
            photoVersion: employee.photoVersion,
            radius: 20,
          ),
          title: Text(employee.name),
          subtitle: Row(
            children: [
              Text(employee.role == 'manager' ? 'Manager' : 'Employee'),
              if (!employee.detailsComplete) ...[
                const SizedBox(width: 8),
                Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  'Details missing',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
          onTap: () => _openSheet(staffId: employee.id),
          trailing: IconButton(
            icon: const Icon(Icons.person_off_outlined),
            tooltip: 'Deactivate',
            onPressed: () => _confirmDeactivate(employee),
          ),
        );
      },
    );
  }

  Widget _buildUnauthorised() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'Not authorised to access this page',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('The staff list is only available to managers.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
            child: const Text('Back to home'),
          ),
        ),
      ],
    );
  }
}
