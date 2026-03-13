import 'package:flutter/material.dart';

import 'screens/groups_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/transactions_screen.dart';

void main() {
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
      home: const MainNavPage(),
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

  static const List<String> _titles = [
    'Home',
    'Groups',
    'Transactions',
    'Profile',
  ];

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(color: colorScheme.onSurface),
        ),
        centerTitle: true,
      ),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 10,
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
    );
  }
}
