import 'package:flutter/material.dart';
import 'models/client_model.dart';
import 'services/api_service.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/edit_clients.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  bool _isLoading = true;
  bool _isAuthorised = true;
  String? _errorMessage;
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
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

      final clients = await ApiService.getClients();

      if (!mounted) return;
      setState(() {
        _isAuthorised = true;
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load clients. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddClientSheet() async {
    final saved = await showEditClientSheet(context);
    if (saved == true) {
      _loadClients();
    }
  }

  Future<void> _openEditClientSheet(Client client) async {
    final saved = await showEditClientSheet(context, client: client);
    if (saved == true) {
      _loadClients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(activeItem: 'Clients'),
      body: RefreshIndicator(
        onRefresh: _loadClients,
        child: _buildBody(),
      ),
      floatingActionButton: _isAuthorised && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _openAddClientSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add client'),
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
                ElevatedButton(onPressed: _loadClients, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    if (_clients.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'No clients found for your company',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _clients.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final client = _clients[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
            ),
          ),
          title: Text(client.name),
          subtitle: Text(
            '${client.fullAddress}${client.phone.isNotEmpty ? ' · ${client.phone}' : ''}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditClientSheet(client),
          ),
        );
      },
    );
  }

  Widget _buildUnauthorised() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Not authorised to access this page',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Viewing clients is only available to managers.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              },
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}