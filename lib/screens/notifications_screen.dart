import 'package:flutter/material.dart';

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
  });

  final String id;
  final String title;
  final String subtitle;
  final _NotificationType type;
  final String category;
  final String actionLabel1;
  final String actionLabel2;
  _NotificationStatus status = _NotificationStatus.pending;
}

class _NotificationsSection {
  _NotificationsSection({required this.title, required this.items});

  final String title;
  final List<_NotificationItem> items;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _primaryBlue = Color(0xFF4CA3EB);
  static const _backgroundStart = Color(0xFFE9F4FF);
  static const _backgroundEnd = Color(0xFFF1F8FF);

  final List<_NotificationsSection> _sections = [
    _NotificationsSection(
      title: 'Payment confirmation',
      items: [
        _NotificationItem(
          id: 'pc1',
          title: 'Alex paid you ₹150.00',
          subtitle: 'Tap to confirm or deny.',
          type: _NotificationType.action,
          category: 'payment_confirmation',
          actionLabel1: 'Confirm',
          actionLabel2: 'Deny',
        ),
        _NotificationItem(
          id: 'pc2',
          title: 'Alex confirmed your payment.',
          subtitle: 'This is a feedback notification.',
          type: _NotificationType.feedback,
          category: 'payment_confirmation',
          actionLabel1: '',
          actionLabel2: '',
        ),
      ],
    ),
    _NotificationsSection(
      title: 'Payment requests',
      items: [
        _NotificationItem(
          id: 'pr1',
          title: 'Jordan has requested ₹250.00',
          subtitle: 'Tap to settle up or reject.',
          type: _NotificationType.action,
          category: 'payment_request',
          actionLabel1: 'Settle up',
          actionLabel2: 'Reject',
        ),
        _NotificationItem(
          id: 'pr2',
          title: 'Jordan has accepted your request and paid.',
          subtitle: 'This is a feedback notification.',
          type: _NotificationType.feedback,
          category: 'payment_request',
          actionLabel1: '',
          actionLabel2: '',
        ),
      ],
    ),
    _NotificationsSection(
      title: 'Group invitations',
      items: [
        _NotificationItem(
          id: 'gi1',
          title: 'Taylor is inviting you to Weekend Trip',
          subtitle: 'Tap to accept or reject.',
          type: _NotificationType.action,
          category: 'group_invite',
          actionLabel1: 'Accept',
          actionLabel2: 'Reject',
        ),
        _NotificationItem(
          id: 'gi2',
          title: 'Taylor has accepted your invitation.',
          subtitle: 'This is a feedback notification.',
          type: _NotificationType.feedback,
          category: 'group_invite',
          actionLabel1: '',
          actionLabel2: '',
        ),
      ],
    ),
  ];

  void _updateStatus(_NotificationItem item, _NotificationStatus status) {
    setState(() {
      item.status = status;
    });
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

  Widget _buildActionButtons(_NotificationItem item) {
    final isPending = item.status == _NotificationStatus.pending;
    if (!isPending) {
      return _buildStatusBadge(item.status);
    }

    final onPrimary = Colors.white;
    final confirmColor = Colors.green;
    final rejectColor = Colors.red;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (item.category == 'payment_confirmation') {
                _updateStatus(item, _NotificationStatus.confirmed);
              } else if (item.category == 'payment_request') {
                _updateStatus(item, _NotificationStatus.settled);
              } else if (item.category == 'group_invite') {
                _updateStatus(item, _NotificationStatus.accepted);
              }
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
              if (item.category == 'payment_confirmation') {
                _updateStatus(item, _NotificationStatus.denied);
              } else if (item.category == 'payment_request') {
                _updateStatus(item, _NotificationStatus.rejected);
              } else if (item.category == 'group_invite') {
                _updateStatus(item, _NotificationStatus.rejected);
              }
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
              if (item.type == _NotificationType.action && item.status != _NotificationStatus.pending)
                _buildStatusBadge(item.status),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _sections
                    .map(
                      (section) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ...section.items.map(_buildNotificationCard),
                          const SizedBox(height: 26),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
