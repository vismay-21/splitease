import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _TransactionFilter { all, paid, received }

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _client = Supabase.instance.client;
  late final String? _currentUserId;
  late final Future<List<_TransactionItem>> _transactionsFuture;
  _TransactionFilter _activeFilter = _TransactionFilter.all;

  @override
  void initState() {
    super.initState();
    _currentUserId = _client.auth.currentUser?.id;
    _transactionsFuture = _loadTransactions();
  }

  Future<List<_TransactionItem>> _loadTransactions() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return [];
    }

    final membershipRows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', currentUserId) as List<dynamic>?;

    final groupIds = (membershipRows ?? <dynamic>[])
        .map((row) => row['group_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (groupIds.isEmpty) {
      return [];
    }

    // Main transaction records (group expenses only)
    final expenseRows = await _client
        .from('group_expenses')
        .select(
          'id, group_id, description, amount, paid_by_user_id, paid_by_name, expense_date, created_at, owes_summary, bill_image_url, group:groups(name)',
        )
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false) as List<dynamic>?;

    final expenses = (expenseRows ?? <dynamic>[]) // ignore: avoid_dynamic_calls
        .map((row) => _TransactionItem.fromExpenseRow(row, currentUserId))
        .toList();

    final all = [...expenses];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  List<_TransactionItem> _filtered(List<_TransactionItem> all) {
    switch (_activeFilter) {
      case _TransactionFilter.paid:
        return all.where((item) => !item.isCredit).toList();
      case _TransactionFilter.received:
        return all.where((item) => item.isCredit).toList();
      case _TransactionFilter.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF4CA3EB);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEAF5FA),
            Color(0xFFD1E6F4),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _transactionsFuture = _loadTransactions();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFilterChips(primaryBlue),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<_TransactionItem>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load transactions. Pull to refresh or check your connection.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }

                    final items = _filtered(snapshot.data ?? []);

                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No activity yet. Add an expense or settle up with a friend to see your transactions here.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _TransactionCard(item: items[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(Color primaryBlue) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterChip(
          label: 'All',
          selected: _activeFilter == _TransactionFilter.all,
          onTap: () => setState(() => _activeFilter = _TransactionFilter.all),
          selectedColor: primaryBlue,
        ),
        _FilterChip(
          label: 'Paid',
          selected: _activeFilter == _TransactionFilter.paid,
          onTap: () => setState(() => _activeFilter = _TransactionFilter.paid),
          selectedColor: Colors.redAccent,
        ),
        _FilterChip(
          label: 'Received',
          selected: _activeFilter == _TransactionFilter.received,
          onTap: () => setState(() => _activeFilter = _TransactionFilter.received),
          selectedColor: Colors.green,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: selected ? selectedColor.withAlpha((0.18 * 255).round()) : Colors.white,
          border: Border.all(
            color: selected ? selectedColor : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? selectedColor : Colors.black87,
              ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.item,
  });

  final _TransactionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(18),
      color: Colors.transparent,
      elevation: 0.8,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetailsDialog(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xE6F9FCFF),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 52,
                    decoration: BoxDecoration(
                      color: item.isCredit ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.groupName.isNotEmpty
                              ? '${item.groupName} · ${item.subtitle}'
                              : item.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${item.isCredit ? '+' : '-'}${_formatAmount(item.amount)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: item.isCredit ? Colors.green : Colors.red,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(item.date),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black45),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetailsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'Amount', value: '₹${_formatAmount(item.amount)}'),
                  const SizedBox(height: 8),
                  _DetailRow(label: 'Date & time', value: _formatDateTime(item.date)),
                  const SizedBox(height: 8),
                  if (item.groupName.isNotEmpty) ...[
                    _DetailRow(label: 'Group', value: item.groupName),
                    const SizedBox(height: 8),
                  ],
                  _DetailRow(label: item.typeLabel, value: item.counterpartyLabel),
                  const SizedBox(height: 8),
                  if (item.details.isNotEmpty) ...[
                    _DetailRow(label: 'Details', value: item.details),
                    const SizedBox(height: 8),
                  ],
                  if (item.billImageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.network(
                          item.billImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) {
                              return child;
                            }
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Text('Unable to load bill image'),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}


class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _TransactionItem {
  _TransactionItem({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isCredit,
    required this.subtitle,
    required this.counterpartyLabel,
    required this.groupName,
    required this.details,
    this.billImageUrl,
    this.settlementStatus,
    this.paymentMethod,
    required this.typeLabel,
  });

  final String id;
  final String title;
  final DateTime date;
  final double amount;
  final bool isCredit;
  final String subtitle;
  final String counterpartyLabel;
  final String groupName;
  final String details;
  final String? billImageUrl;
  final String? settlementStatus;
  final String? paymentMethod;
  final String typeLabel;

  factory _TransactionItem.fromExpenseRow(dynamic row, String currentUserId) {
    final amount = _asDouble(row['amount']);
    final paidByUserId = row['paid_by_user_id']?.toString() ?? '';
    final putativeName = row['paid_by_name']?.toString() ?? 'Unknown';
    final groupName = (row['group'] as Map?)?['name']?.toString() ?? '';
    final owesSummary = row['owes_summary']?.toString() ?? '';
    final billImageUrl = row['bill_image_url']?.toString();

    final isCredit = paidByUserId != currentUserId;

    final counterparty = isCredit ? 'Paid by $putativeName' : 'Split with group';

    return _TransactionItem(
      id: row['id']?.toString() ?? UniqueKey().toString(),
      title: row['description']?.toString() ?? 'Expense',
      date: _parseDate(row['created_at'] ?? row['expense_date']),
      amount: amount,
      isCredit: isCredit,
      subtitle: counterparty,
      counterpartyLabel: counterparty,
      groupName: groupName,
      details: owesSummary,
      billImageUrl: billImageUrl,
      settlementStatus: null,
      paymentMethod: null,
      typeLabel: 'Expense',
    );
  }
}

String _formatAmount(double amount) {
  return amount.toStringAsFixed(2);
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${_monthName(local.month)} ${local.day}, ${local.year} · ${_pad(local.hour)}:${_pad(local.minute)}';
}

String _monthName(int month) {
  const names = [
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
  return names[month - 1];
}

String _pad(int value) => value.toString().padLeft(2, '0');

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  try {
    return DateTime.parse(value.toString()).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

double _asDouble(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  final parsed = double.tryParse(value.toString());
  return parsed ?? 0;
}

