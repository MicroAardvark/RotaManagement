import 'package:flutter/material.dart';
import 'models/employee_model.dart';
import 'services/api_service.dart';
import 'widgets/app_top_bar.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Employee> _employees = [];
  bool _isLoading = true;
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
      final employees = await ApiService.getCurrentEmployees();
      if (!mounted) return;
      setState(() {
        _employees = employees..sort((a, b) => a.name.compareTo(b.name));
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
      appBar: const AppTopBar(activeItem: 'People', isManager: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : ListView.separated(
                  itemCount: _employees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(employee.name),
                      subtitle: Text(employee.role),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_off_outlined),
                        tooltip: 'Deactivate',
                        onPressed: () => _confirmDeactivate(employee),
                      ),
                    );
                  },
                ),
    );
  }
}