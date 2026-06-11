import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splitease/utils/algo.dart';

import 'groups_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  late Future<_HomeSummary> _summaryFuture;
  late Future<List<_HomeRecentTransaction>> _recentTransactionsFuture;

  static const _primaryBlue = Color(0xFF4CA3EB);
  static const _cardBackground = Colors.white;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
    _recentTransactionsFuture = _loadRecentTransactions();
  }

  Future<_HomeSummary> _loadSummary() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const _HomeSummary(toPay: 0, toReceive: 0);
    }

    final membershipRows = await _client
      .from('group_members')
      .select('group_id,balance')
      .eq('user_id', userId) as List<dynamic>;

    final groupIds = membershipRows
        .map((row) => row['group_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (groupIds.isEmpty) {
      return const _HomeSummary(toPay: 0, toReceive: 0);
    }

    final splitRows = await _client
        .from('group_settlements')
        .select('group_id,payer_user_id,receiver_user_id,amount,method,status')
        .inFilter('group_id', groupIds)
        .eq('method', 'split')
        .eq('status', 'pending') as List<dynamic>;

    final fallbackBalanceByGroupId = <String, double>{};
    for (final row in membershipRows) {
      final groupId = row['group_id']?.toString() ?? '';
      if (groupId.isEmpty) {
        continue;
      }
      final balance = _asDouble(row['balance']);
      fallbackBalanceByGroupId[groupId] = balance;
    }

    final obligationsByGroup = <String, List<SettlementTransfer>>{};
    for (final row in splitRows) {
      final groupId = row['group_id']?.toString() ?? '';
      final payerUserId = row['payer_user_id']?.toString() ?? '';
      final payeeUserId = row['receiver_user_id']?.toString() ?? '';
      final amount = _asDouble(row['amount']);
      if (groupId.isEmpty || payerUserId.isEmpty || payeeUserId.isEmpty || amount <= 0) {
        continue;
      }

      obligationsByGroup.putIfAbsent(groupId, () => <SettlementTransfer>[]).add(
            SettlementTransfer(
              payerUserId: payerUserId,
              payeeUserId: payeeUserId,
              amountCents: (amount * 100).round(),
            ),
          );
    }

    var toPay = 0.0;
    var toReceive = 0.0;

    for (final groupId in groupIds) {
      final obligations = obligationsByGroup[groupId] ?? <SettlementTransfer>[];

      if (obligations.isNotEmpty) {
        final minimized = computeMinimumSettlements(obligations: obligations);
        for (final transfer in minimized) {
          if (transfer.payerUserId == userId) {
            toPay += transfer.amountCents / 100;
          }
          if (transfer.payeeUserId == userId) {
            toReceive += transfer.amountCents / 100;
          }
        }
      } else {
        final fallback = fallbackBalanceByGroupId[groupId] ?? 0;
        if (fallback < 0) {
          toPay += -fallback;
        } else if (fallback > 0) {
          toReceive += fallback;
        }
      }
    }

    return _HomeSummary(toPay: toPay, toReceive: toReceive);
  }

  static double _asDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _formatSignedAmount(double value, {required bool positive}) {
    final sign = positive ? '+' : '-';
    return '$sign${value.toStringAsFixed(2)}';
  }

  Future<List<_HomeRecentTransaction>> _loadRecentTransactions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return <_HomeRecentTransaction>[];
    }

    final membershipRows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId) as List<dynamic>;

    final groupIds = membershipRows
        .map((row) => row['group_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (groupIds.isEmpty) {
      return <_HomeRecentTransaction>[];
    }

    final rows = await _client
        .from('group_expenses')
        .select(
          'description,amount,paid_by_user_id,created_at,group:groups(name)',
        )
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false)
        .limit(4) as List<dynamic>;

    return rows.map((row) {
      final amount = _asDouble(row['amount']);
      final paidByUserId = row['paid_by_user_id']?.toString() ?? '';
      final groupName = (row['group'] as Map?)?['name']?.toString() ?? '';
      final date = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
      final isCredit = paidByUserId != userId;

      return _HomeRecentTransaction(
        title: row['description']?.toString() ?? 'Expense',
        subtitle: '${groupName.isNotEmpty ? '$groupName · ' : ''}${_formatRelativeDateTime(date)}',
        amount: _formatSignedAmount(amount, positive: isCredit),
        amountColor: isCredit ? Colors.green : Colors.red,
        icon: Icons.receipt_long_outlined,
      );
    }).toList();
  }

  static String _formatRelativeDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(date).inDays;

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    final timeText = '$hour:$minute $suffix';

    if (difference == 0) {
      return 'Today · $timeText';
    }
    if (difference == 1) {
      return 'Yesterday · $timeText';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day} · $timeText';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? const _HomeSummary(toPay: 0, toReceive: 0);

        return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF5FA), Color(0xFFD1E6F4)],
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
                          child: ClipOval(
                            child: Image.asset(
                              'web/icons/Icon-512.png',
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                         const Text(
                '   BATVAARA',
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
                        title: 'TO PAY',
                        amount: _formatSignedAmount(summary.toPay, positive: false),
                        amountColor: Colors.red,
                        icon: Icons.arrow_upward,
                        background: _cardBackground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OweCard(
                        title: 'TO RECEIVE',
                        amount: _formatSignedAmount(summary.toReceive, positive: true),
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
                FutureBuilder<List<_HomeRecentTransaction>>(
                  future: _recentTransactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final items = snapshot.data ?? <_HomeRecentTransaction>[];
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'No transactions yet.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                      );
                    }

                    return Column(
                      children: items
                          .map(
                            (item) => _TransactionTile(
                              icon: item.icon,
                              title: item.title,
                              subtitle: item.subtitle,
                              amount: item.amount,
                              amountColor: item.amountColor,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
        );
      },
    );
  }
}

class _HomeSummary {
  const _HomeSummary({required this.toPay, required this.toReceive});

  final double toPay;
  final double toReceive;
}

class _HomeRecentTransaction {
  const _HomeRecentTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final IconData icon;
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
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
        ),
      ),
    );
  }
}

class _GroupBar extends StatefulWidget {
  const _GroupBar({required this.primaryColor});

  final Color primaryColor;

  @override
  State<_GroupBar> createState() => _GroupBarState();
}

class _GroupBarState extends State<_GroupBar> {
  final SupabaseClient _client = Supabase.instance.client;
  late Future<List<_HomeGroupShortcut>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
  }

  Future<List<_HomeGroupShortcut>> _loadGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return <_HomeGroupShortcut>[];
    }

    final membershipRows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId) as List<dynamic>;

    final groupIds = membershipRows
        .map((row) => row['group_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (groupIds.isEmpty) {
      return <_HomeGroupShortcut>[];
    }

    final groupRows = await _client
        .from('groups')
        .select('id,name,icon')
        .inFilter('id', groupIds)
        .order('name', ascending: true) as List<dynamic>;

    return groupRows
        .map(
          (row) => _HomeGroupShortcut(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? 'Group',
            iconName: row['icon']?.toString() ?? 'group',
          ),
        )
        .where((group) => group.id.isNotEmpty)
        .toList();
  }

  static IconData _iconFor(String iconName) {
    switch (iconName) {
      case 'flight':
        return Icons.flight_takeoff;
      case 'home':
        return Icons.home;
      case 'sports':
        return Icons.sports_soccer;
      case 'food':
        return Icons.restaurant;
      default:
        return Icons.group;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: widget.primaryColor.withAlpha(36),
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
            child: FutureBuilder<List<_HomeGroupShortcut>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                final groups = snapshot.data ?? <_HomeGroupShortcut>[];

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 62,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (groups.isEmpty) {
                  return const SizedBox(
                    height: 78,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No groups yet'),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: groups.map((group) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Tooltip(
                          message: group.name,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              GroupsScreen.setPendingGroupPopup(groupId: group.id);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const GroupsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.black.withAlpha(31)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _iconFor(group.iconName),
                                    size: 24,
                                    color: Colors.black87,
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      group.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeGroupShortcut {
  const _HomeGroupShortcut({
    required this.id,
    required this.name,
    required this.iconName,
  });

  final String id;
  final String name;
  final String iconName;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.white.withOpacity(0.78),
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
        ),
      ),
    );
  }
}
