import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/groups_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/transactions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Run with --dart-define values.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SpliTease',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CA3EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFEDF5FB),
      ),
      home: const StartupSetupGate(),
    );
  }
}

class StartupSetupGate extends StatefulWidget {
  const StartupSetupGate({super.key});

  @override
  State<StartupSetupGate> createState() => _StartupSetupGateState();
}

class _StartupSetupGateState extends State<StartupSetupGate> {
  static const List<String> _requiredTables = <String>[
    'groups',
    'group_members',
    'group_invitations',
    'group_expenses',
    'group_settlements',
  ];

  bool _isChecking = true;
  bool _skipChecker = false;
  List<String> _missingTables = <String>[];
  String? _checkError;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    if (_skipChecker) {
      setState(() {
        _skipChecker = false;
      });
    }

    setState(() {
      _isChecking = true;
      _missingTables = <String>[];
      _checkError = null;
    });

    final client = Supabase.instance.client;
    final missing = <String>[];

    for (final table in _requiredTables) {
      try {
        await client.from(table).select('*').limit(1);
      } on PostgrestException catch (error) {
        if (_isMissingTableError(error)) {
          missing.add(table);
          continue;
        }

        if (!_isPermissionError(error)) {
          _checkError = '[${error.code ?? 'unknown'}] ${error.message}';
        }
      } catch (_) {
        _checkError = 'Unable to verify backend setup right now.';
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _missingTables = missing;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_skipChecker) {
      return const AuthGate();
    }

    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_missingTables.isEmpty && _checkError == null) {
      return const AuthGate();
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD1E6F7)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 46,
                    color: Color(0xFF1D6CAB),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Backend Setup Required',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _missingTables.isNotEmpty
                        ? 'Could not load groups because required tables are missing.'
                        : 'Could not verify backend setup.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_missingTables.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Missing: ${_missingTables.join(', ')}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (_checkError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _checkError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Run SQL migration:\nsupabase/migrations/20260313_groups_schema.sql',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _checkSetup,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recheck Setup'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _skipChecker = true;
                      });
                    },
                    child: const Text('Continue Anyway'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isMissingTableError(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    return code == '42P01' ||
        code == 'PGRST205' ||
        message.contains('could not find the table') ||
        (message.contains('relation') && message.contains('does not exist'));
  }

  bool _isPermissionError(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    return code == '42501' || message.contains('permission denied');
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;

        if (session != null) {
          return const MainNavPage();
        }

        return const LoginScreen();
      },
    );
  }
}

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;


  static final List<Widget> _pages = [
    const HomeScreen(),
    const GroupsScreen(),
    const TransactionsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {},
              backgroundColor: Colors.black,
              tooltip: 'Add expense',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: NavigationBar(
              backgroundColor: const Color.fromRGBO(255, 255, 255, 0.75),
              surfaceTintColor: Colors.transparent,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: 'Groups',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_horiz_outlined),
                  selectedIcon: Icon(Icons.swap_horiz),
                  label: 'Transactions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
