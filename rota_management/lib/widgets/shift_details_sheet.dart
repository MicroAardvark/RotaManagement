import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_model.dart';
import '../models/employee_model.dart';
import '../services/api_service.dart';

enum ShiftSheetResult { edit, deleted }

/// Opens a bottom sheet showing the details of a single shift.
/// Pass [employee] when viewing from a manager context (e.g. the
/// edit-rota grid) so the sheet can show who the shift belongs to;
/// omit it when a user is viewing their own shift.
Future<ShiftSheetResult?> showShiftDetails(
  BuildContext context,
  Shift shift, {
  Employee? employee,
  bool canManage = false,
}) {
  return showModalBottomSheet<ShiftSheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ShiftDetailsSheet(
      shift: shift,
      employee: employee,
      canManage: canManage,
    ),
  );
}

class ShiftDetailsSheet extends StatelessWidget {
  final Shift shift;
  final Employee? employee;
  final bool canManage;

  const ShiftDetailsSheet({
    super.key,
    required this.shift,
    this.employee,
    this.canManage = false,
  });

   Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete shift'),
        content: const Text('Remove this shift from the rota? This cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiService.deleteShift(shift.id);
      if (!context.mounted) return;
      Navigator.of(context).pop(ShiftSheetResult.deleted);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Failed to delete shift')),
      );
    }
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
          Text('Shift details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (employee != null) ...[
            DetailRow(
              icon: Icons.person_outline,
              label: 'Employee',
              value: employee!.name,
            ),
            const SizedBox(height: 12),
          ],
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
            DetailRow(icon: Icons.work_outline, label: 'Job Type', value: shift.role),
          ],
          if (shift.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            DetailRow(icon: Icons.notes_outlined, label: 'Notes', value: shift.notes),
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
          if (shift.clientAccess.isNotEmpty) ...[
            const SizedBox(height: 12),
            DetailRow(
              icon: Icons.key_outlined,
              label: 'Access',
              value: shift.clientAccess,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),

          if (canManage) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    onPressed: () => Navigator.of(context).pop(ShiftSheetResult.edit),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    onPressed: () => _confirmDelete(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}