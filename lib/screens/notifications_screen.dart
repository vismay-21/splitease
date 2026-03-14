import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:splitease/screens/groups_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotificationStatus { pending, confirmed, denied, settled, rejected, accepted }

enum _NotificationType { action, feedback }

class _NotificationItem {
  _NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.category,
    required this.actionLabel1,
    required this.actionLabel2,
    required this.date,
    this.groupId,
    this.senderUserId,
  });

  final String id;
  final String title;
  final String subtitle;
  final _NotificationType type;
  final String category;
  final String actionLabel1;
  final String actionLabel2;
  final DateTime date;
  final String? groupId;
  final String? senderUserId;
  _NotificationStatus status = _NotificationStatus.pending;

  factory _NotificationItem.fromDb(Map<String, dynamic> row) {
    final amount = _asDouble(row['amount']);
    final category = row['category']?.toString() ?? 'payment_received_confirmation';
    final senderName = row['sender_name']?.toString().trim().isNotEmpty == true
        ? row['sender_name']?.toString().trim() ?? 'Someone'
        : 'Someone';
    final methodValue = row['method']?.toString().toLowerCase() ?? '';
    final method = methodValue == 'cash' ? 'Cash' : 'UPI';
    final statusText = row['status']?.toString().toLowerCase() ?? 'pending';

    final isPaymentRequest = category == 'payment_request';

    final item = _NotificationItem(
      id: row['id']?.toString() ?? '',
      title: isPaymentRequest
          ? '$senderName has requested ₹${amount.toStringAsFixed(2)}'
          : '$senderName has paid you ₹${amount.toStringAsFixed(2)} by $method. Did you receive it?',
      subtitle: isPaymentRequest
          ? 'Tap Pay to settle this request.'
          : 'Tap Yes if received, or No if not received.',
      type: _NotificationType.action,
      category: category,
      actionLabel1: isPaymentRequest ? 'Pay' : 'Yes',
      actionLabel2: isPaymentRequest ? '' : 'No',
      date: DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      groupId: row['group_id']?.toString(),
      senderUserId: row['sender_user_id']?.toString(),
    );

    item.status = _statusFromDb(statusText);
    return item;
  }

  static _NotificationStatus _statusFromDb(String status) {
    switch (status) {
      case 'confirmed':
        return _NotificationStatus.confirmed;
      case 'denied':
        return _NotificationStatus.denied;
      case 'settled':
        return _NotificationStatus.settled;
      case 'rejected':
        return _NotificationStatus.rejected;
      case 'accepted':
        return _NotificationStatus.accepted;
      default:
        return _NotificationStatus.pending;
    }
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
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _primaryBlue = Color(0xFF4CA3EB);
  static const _backgroundStart = Color(0xFFEAF5FA);
  static const _backgroundEnd = Color(0xFFD1E6F4);

  final SupabaseClient _client = Supabase.instance.client;
  bool _isLoading = true;
  String? _loadError;
  List<_NotificationItem> _items = <_NotificationItem>[];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _items = <_NotificationItem>[];
        _loadError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final rows = await _client
          .from('group_notifications')
          .select(
            'id,group_id,sender_user_id,sender_name,amount,method,status,created_at,category',
          )
          .eq('receiver_user_id', user.id)
          .order('created_at', ascending: false) as List<dynamic>;

      final items = rows
          .map((row) => _NotificationItem.fromDb(Map<String, dynamic>.from(row as Map)))
          .where((item) => item.id.isNotEmpty)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = 'Could not load notifications (${error.message}).';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load notifications right now.';
      });
    }
  }

  void _updateStatus(_NotificationItem item, _NotificationStatus status) {
    setState(() {
      item.status = status;
    });

    final dbStatus = switch (status) {
      _NotificationStatus.confirmed => 'confirmed',
      _NotificationStatus.denied => 'denied',
      _NotificationStatus.settled => 'settled',
      _NotificationStatus.rejected => 'rejected',
      _NotificationStatus.accepted => 'accepted',
      _NotificationStatus.pending => 'pending',
    };

    _client
        .from('group_notifications')
        .update({
          'status': dbStatus,
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', item.id)
        .then((_) {})
        .catchError((_) {});
  }

  Widget _buildStatusBadge(_NotificationStatus status) {
    final text = () {
      switch (status) {
        case _NotificationStatus.confirmed:
          return 'Confirmed';
        case _NotificationStatus.denied:
          return 'Denied';
        case _NotificationStatus.settled:
          return 'Settled';
        case _NotificationStatus.rejected:
          return 'Rejected';
        case _NotificationStatus.accepted:
          return 'Accepted';
        case _NotificationStatus.pending:
          return 'Pending';
      }
    }();

    final color = () {
      switch (status) {
        case _NotificationStatus.confirmed:
        case _NotificationStatus.settled:
        case _NotificationStatus.accepted:
          return Colors.green;
        case _NotificationStatus.denied:
        case _NotificationStatus.rejected:
          return Colors.red;
        case _NotificationStatus.pending:
          return Colors.grey;
      }
    }();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    final month = months[date.month - 1];
    return '$month ${date.day}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minutes = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minutes $suffix';
  }

  Widget _buildActionButtons(_NotificationItem item) {
    final isPending = item.status == _NotificationStatus.pending;
    if (!isPending) {
      return _buildStatusBadge(item.status);
    }

    if (item.category == 'payment_request') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _updateStatus(item, _NotificationStatus.confirmed);

            final groupId = item.groupId ?? '';
            final counterpartyUserId = item.senderUserId ?? '';
            if (groupId.isNotEmpty && counterpartyUserId.isNotEmpty) {
              GroupsScreen.setPendingSettleUpIntent(
                groupId: groupId,
                counterpartyUserId: counterpartyUserId,
              );
            }

            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GroupsScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A4A8F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text(item.actionLabel1),
        ),
      );
    }

    final onPrimary = Colors.white;
    final confirmColor = Colors.green;
    final rejectColor = Colors.red;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              _updateStatus(item, _NotificationStatus.confirmed);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(item.actionLabel1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              _updateStatus(item, _NotificationStatus.denied);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: rejectColor,
              foregroundColor: onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(item.actionLabel2),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(_NotificationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(18),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(item.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withAlpha(150),
                          ),
                        ),
                        if (item.type == _NotificationType.action && item.status != _NotificationStatus.pending) ...[
                          const SizedBox(height: 0.5),
                          _buildStatusBadge(item.status),
                        ],
                        const SizedBox(height: 0.5),
                        Text(
                          _formatDate(item.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withAlpha(166),
                  ),
                ),
                const SizedBox(height: 12),
                if (item.type == _NotificationType.action) _buildActionButtons(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = List<_NotificationItem>.from(_items)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Notifications'),
        foregroundColor: _primaryBlue,
        iconTheme: const IconThemeData(color: _primaryBlue),
      ),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundStart, _backgroundEnd],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      _loadError!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB33A2E),
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withAlpha(140),
                      ),
                    ),
                  )
                else
                  ...items.map(_buildNotificationCard),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
