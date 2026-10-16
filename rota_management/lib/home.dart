import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'models/employee_model.dart';
import 'models/shift_model.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/shift_details_sheet.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isManager = false;
  bool _isLoading = true;
  String? _errorMessage;

  Shift? _nextShift;
  List<Employee> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check manager status first, since it determines what else we fetch
      final managerStatus = await ApiService.checkManager();

      final nextShift = await ApiService.getNextShift();

      List<Employee> employees = [];
      if (managerStatus) {
        employees = await ApiService.getCurrentEmployees();
      }

      if (!mounted) return;
      setState(() {
        isManager = managerStatus;
        _nextShift = nextShift;
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load your rota. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:  AppTopBar(activeItem: 'Home', isManager: isManager),
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        // ListView so RefreshIndicator's pull-to-refresh still works on error
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Text(_errorMessage!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadHomeData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildNextShiftCard(),
        if (isManager) ...[
          const SizedBox(height: 24),
          _buildEmployeeList(),
        ],
      ],
    );
  }

  Widget _buildNextShiftCard() {
    if (_nextShift == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No upcoming shifts scheduled'),
        ),
      );
    }

    final shift = _nextShift!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your next shift', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: DateFormat('EEEE d MMMM yyyy').format(shift.startTime),
            ),
            const SizedBox(height: 12),
            DetailRow(
              icon: Icons.schedule_outlined,
              label: 'Time',
              value: '${DateFormat('HH:mm').format(shift.startTime)} – '
                  '${DateFormat('HH:mm').format(shift.endTime)}',
            ),
            if (shift.role.isNotEmpty) ...[
              const SizedBox(height: 12),
              DetailRow(icon: Icons.work_outline, label: 'Role / area', value: shift.role),
            ],
            if (shift.clientName.isNotEmpty) ...[
              const SizedBox(height: 12),
              DetailRow(
                icon: Icons.business_outlined,
                label: 'Client',
                value: shift.clientFullAddress.isNotEmpty
                    ? '${shift.clientName}, ${shift.clientFullAddress}'
                    : shift.clientName,
              ),
            ],
            if (shift.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              DetailRow(icon: Icons.notes_outlined, label: 'Notes', value: shift.notes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current employees',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_employees.isEmpty)
          const Text('No employees found')
        else
          ...List.generate(_employees.length, (i) {
            final employee = _employees[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(employee.name),
                subtitle: Text(employee.role),
              ),
            );
          }),
      ],
    );
  }
}