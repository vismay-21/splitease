import 'package:flutter/material.dart';

import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _primaryBlue = Color(0xFF4CA3EB);
  static const _cardBackground = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9F4FF), Color(0xFFF1F8FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _primaryBlue.withAlpha(46),
                          child: Icon(
                            Icons.person,
                            color: _primaryBlue,
                            size: 24,
                          ),
                        ),
                         const Text(
                'BATVAARA',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E5D36),
                  letterSpacing: 0.4,
                ),
              ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _primaryBlue.withAlpha(46),
                      child: IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.notifications_none,
                          color: _primaryBlue,
                          size: 24,
                        ),
                        tooltip: 'Notifications',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _OweCard(
                        title: 'To Pay',
                        amount: '-250.50',
                        amountColor: Colors.red,
                        icon: Icons.arrow_upward,
                        background: _cardBackground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OweCard(
                        title: 'To Receive',
                        amount: '+280.75',
                        amountColor: Colors.green,
                        icon: Icons.arrow_downward,
                        background: _cardBackground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _GroupBar(primaryColor: _primaryBlue),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryBlue,
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TransactionTile(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Grocery',
                  subtitle: 'Today · 10:24 AM',
                  amount: '-20.50',
                  amountColor: Colors.red,
                ),
                _TransactionTile(
                  icon: Icons.coffee_outlined,
                  title: 'Coffee with Sam',
                  subtitle: 'Yesterday · 5:12 PM',
                  amount: '+12.00',
                  amountColor: Colors.green,
                ),
                _TransactionTile(
                  icon: Icons.car_rental_outlined,
                  title: 'Taxi share',
                  subtitle: 'Sep 12 · 11:00 AM',
                  amount: '-35.20',
                  amountColor: Colors.red,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OweCard extends StatelessWidget {
  const _OweCard({
    required this.title,
    required this.amount,
    required this.amountColor,
    required this.icon,
    required this.background,
  });

  final String title;
  final String amount;
  final Color amountColor;
  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: amountColor.withAlpha(41),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: amountColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBar extends StatelessWidget {
  const _GroupBar({required this.primaryColor});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final groups = [
      {'label': 'Trip', 'icon': Icons.airplanemode_active},
      {'label': 'Food', 'icon': Icons.local_pizza},
      {'label': 'Rent', 'icon': Icons.home_outlined},
      {'label': 'Gym', 'icon': Icons.fitness_center},
      {'label': 'Events', 'icon': Icons.event},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(36),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Groups',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: groups.map((group) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.black.withAlpha(31)),
                      ),
                      child: Center(
                        child: Icon(
                          group['icon'] as IconData,
                          size: 26,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.black87, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
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
