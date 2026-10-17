import 'package:flutter/material.dart';
import 'models/job_type_model.dart';
import 'services/api_service.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/job_type_sheet.dart';

/// Manager-only list of the company's job types. Each job type sets how
/// long its shifts last.
class JobTypesScreen extends StatefulWidget {
  const JobTypesScreen({super.key});

  @override
  State<JobTypesScreen> createState() => _JobTypesScreenState();
}

class _JobTypesScreenState extends State<JobTypesScreen> {
  bool _isLoading = true;
  bool _isAuthorised = true;
  String? _errorMessage;
  List<JobType> _jobTypes = [];

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
      final jobTypes = await ApiService.getJobTypes();
      if (!mounted) return;
      setState(() {
        _isAuthorised = true;
        _jobTypes = jobTypes..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load job types. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSheet({JobType? jobType}) async {
    final saved = await showJobTypeSheet(context, jobType: jobType);
    if (saved == true && mounted) _load();
  }

  Future<void> _confirmDelete(JobType jobType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${jobType.name}?'),
        content: const Text(
          "Existing shifts keep their times. You'll need to choose a new "
          'job type if you edit one of them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.deleteJobType(jobType.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${jobType.name} deleted')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Failed to delete job type')),
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
              icon: const Icon(Icons.add),
              label: const Text('Add job type'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (!_isAuthorised) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Not authorised to access this page',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Job types are only available to managers.', textAlign: TextAlign.center),
        ],
      );
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

    if (_jobTypes.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No job types yet. Add one to start booking shifts.')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _jobTypes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final jobType = _jobTypes[index];
        return ListTile(
          leading: const Icon(Icons.work_outline),
          title: Text(jobType.name),
          subtitle: Text(formatMinutes(jobType.lengthMinutes)),
          onTap: () => _openSheet(jobType: jobType),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(jobType),
          ),
        );
      },
    );
  }
}
