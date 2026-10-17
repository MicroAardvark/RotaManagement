import 'package:flutter/material.dart';
import 'clients.dart';
import 'home.dart';
import 'job_types.dart';
import 'login.dart';
import 'navigation.dart';
import 'profile.dart';
import 'rota.dart';
import 'rota_edit.dart';
import 'services/api_service.dart';
import 'services/session_store.dart';
import 'settings.dart';
import 'staff.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rota Manager',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/rota': (context) => const RotaScreen(),
        '/rota/edit': (context) => const RotaEditScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/clients': (context) => const ClientsScreen(),
        '/staff': (context) => const StaffScreen(),
        '/job-types': (context) => const JobTypesScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      home: const StartupGate(),
    );
  }
}

/// First screen: goes straight to Home if the session cookie is still
/// valid ("Keep me signed in"), otherwise shows the welcome page. It
/// also loads the current user into SessionStore for the top bar, which
/// still happens on a refresh of a deep link because this page sits
/// under the restored one.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    CurrentUser? user;
    try {
      user = await ApiService.getMe();
    } catch (_) {
      user = null; // server unreachable: show the welcome page
    }
    if (!mounted) return;
    // On a refresh of a deep link (e.g. /#/rota) this gate sits under the
    // restored page; only redirect when it's the page being shown.
    final isShowing = ModalRoute.of(context)?.isCurrent ?? true;
    if (user != null && isShowing) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const MyHomePage(title: 'Rota Manager');
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.calendar_month,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Manage your shifts, all in one place.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Log In', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}