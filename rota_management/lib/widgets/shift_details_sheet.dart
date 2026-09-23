import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_model.dart';
import '../models/employee_model.dart';

/// Opens a bottom sheet showing the details of a single shift.
/// Pass [employee] when viewing from a manager context (e.g. the
/// edit-rota grid) so the sheet can show who the shift belongs to;
/// omit it when a user is viewing their own shift.
Future<void> showShiftDetails(
  BuildContext context,
  Shift shift, {
  Employee? employee,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ShiftDetailsSheet(shift: shift, employee: employee),
  );
}

class ShiftDetailsSheet extends StatelessWidget {
  final Shift shift;
  final Employee? employee;

  const ShiftDetailsSheet({super.key, required this.shift, this.employee});

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
          const SizedBox(height: 20),
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