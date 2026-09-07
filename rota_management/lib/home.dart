import 'package:flutter/material.dart';
import 'rota.dart';
import 'services/api_service.dart';
import 'models/employee_model.dart';
import 'models/shift_model.dart';
import 'new_employee.dart';

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
      appBar: AppBar(
        title: const Text('Rota Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            onPressed: () {
              // TODO: navigate to account screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Rota',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RotaScreen()),
              ); 
            },
          ),
          IconButton(
            icon: const Icon(Icons.event_busy_outlined),
            tooltip: 'Absence',
            onPressed: () {
              // TODO: navigate to absence screen
            },
          ),
          isManager
              ? IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'Add employee',
                onPressed: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const NewEmployeeScreen()),
                  );
                  if (added == true) {
                    _loadHomeData(); // or _loadHomeData(), refresh whichever screen called it
                  }
                },
              )
              : const SizedBox.shrink(),
        ],
      ),
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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule_outlined),
        title: const Text('Your next shift'),
        subtitle: Text(
          _nextShift != null
              ? _nextShift!.formattedDate // e.g. "Tue 9 Sep, 09:00–17:00"
              : 'No upcoming shifts scheduled',
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