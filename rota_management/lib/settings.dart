import 'package:flutter/material.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/edit_job_types.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(activeItem: 'Settings'),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.work_outline),
            title: const Text('Edit Job Types'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showEditJobTypesSheet(context),
          ),
        ],
      ),
    );
  }
}