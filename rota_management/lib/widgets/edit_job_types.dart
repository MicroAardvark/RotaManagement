import 'package:flutter/material.dart';
import '../models/job_type_model.dart';
import '../services/api_service.dart';

Future<void> showEditJobTypesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const EditJobTypesSheet(),
  );
}

class EditJobTypesSheet extends StatefulWidget {
  const EditJobTypesSheet({super.key});

  @override
  State<EditJobTypesSheet> createState() => _EditJobTypesSheetState();
}

class _EditJobTypesSheetState extends State<EditJobTypesSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<JobType> _jobTypes = [];

  final _newNameController = TextEditingController();
  final _newLengthController = TextEditingController();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadJobTypes();
  }

  @override
  void dispose() {
    _newNameController.dispose();
    _newLengthController.dispose();
    super.dispose();
  }

  Future<void> _loadJobTypes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jobTypes = await ApiService.getJobTypes();
      if (!mounted) return;
      setState(() {
        _jobTypes = jobTypes;
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

  Future<void> _addJobType() async {
    final name = _newNameController.text.trim();
    final length = int.tryParse(_newLengthController.text.trim());

    if (name.isEmpty) return;
    if (length == null || length < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid length in minutes')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      final created = await ApiService.addJobType(name, length);
      if (!mounted) return;
      setState(() {
        _jobTypes = [..._jobTypes, created];
        _newNameController.clear();
        _newLengthController.clear();
        _isAdding = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add job type. Please try again.')),
      );
    }
  }

  Future<void> _editJobType(JobType jobType) async {
    final nameController = TextEditingController(text: jobType.name);
    final lengthController = TextEditingController(text: jobType.lengthMinutes.toString());

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit job type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Length (minutes)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'length': lengthController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final newName = result['name']!;
    final newLength = int.tryParse(result['length']!);

    if (newName.isEmpty || newLength == null || newLength < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name and length')),
      );
      return;
    }

    if (newName == jobType.name && newLength == jobType.lengthMinutes) return;

    try {
      final updated = await ApiService.updateJobType(jobType.id, newName, newLength);
      if (!mounted) return;
      setState(() {
        _jobTypes = _jobTypes
            .map((jt) => jt.id == updated.id ? updated : jt)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update job type. Please try again.')),
      );
    }
  }

  Future<void> _deleteJobType(JobType jobType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete job type'),
        content: Text('Delete "${jobType.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previous = _jobTypes;
    setState(() {
      _jobTypes = _jobTypes.where((jt) => jt.id != jobType.id).toList();
    });

    try {
      await ApiService.deleteJobType(jobType.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _jobTypes = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete job type. Please try again.')),
      );
    }
  }

  String _formatLength(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}min';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job types', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildBody(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newNameController,
                  decoration: const InputDecoration(
                    labelText: 'New job type',
                    hintText: 'e.g. Deep cleaning',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _newLengthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    hintText: 'e.g. 90',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isAdding ? null : _addJobType,
                icon: _isAdding
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          Text(_errorMessage!),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _loadJobTypes, child: const Text('Retry')),
        ],
      );
    }

    if (_jobTypes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No job types have been added yet.'),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _jobTypes.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final jobType = _jobTypes[index];
          return ListTile(
            title: Text(jobType.name),
            subtitle: Text(_formatLength(jobType.lengthMinutes)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editJobType(jobType),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteJobType(jobType),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}