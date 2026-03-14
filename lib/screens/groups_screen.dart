import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splitease/screens/unqually_screen.dart';
import 'package:splitease/utils/algo.dart';
import 'package:splitease/utils/upi_deepLink.dart';

final _fakeGroups = [
  GroupSummary(
    id: 'grp1',
    name: 'Trip to Goa',
    icon: 'airplanemode_active',
    createdByUserId: 'Ayaan K.',
    createdByName: 'Ayaan K.',
    createdAt: DateTime(2026, 3, 1),
    totalExpenses: 1890.50,
    totalOwed: 560.25,
    balance: -250.50,
    memberCount: 5,
    settlementStatus: 'Active',
  ),
  GroupSummary(
    id: 'grp2',
    name: 'Room Rent',
    icon: 'home',
    createdByUserId: 'Sneh',
    createdByName: 'Sneh',
    createdAt: DateTime(2026, 3, 2),
    totalExpenses: 3450.00,
    totalOwed: 1000.00,
    balance: 280.75,
    memberCount: 3,
    settlementStatus: 'Active',
  ),
];

class _GroupTransaction {
  const _GroupTransaction({
    required this.sortKey,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.icon,
    this.expenseDetails,
    this.settlementDetails,
  });

  final DateTime sortKey;
  final String date;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final IconData icon;
  final _ExpenseTransactionDetails? expenseDetails;
  final _SettlementTransactionDetails? settlementDetails;
}

class _ExpenseTransactionDetails {
  const _ExpenseTransactionDetails({
    required this.expenseName,
    required this.totalAmount,
    required this.paidBy,
    required this.participants,
  });

  final String expenseName;
  final double totalAmount;
  final List<_PaidByLine> paidBy;
  final List<String> participants;
}

class _PaidByLine {
  const _PaidByLine({required this.memberName, required this.amount});

  final String memberName;
  final double amount;
}

class _SettlementTransactionDetails {
  const _SettlementTransactionDetails({
    required this.debtorUserId,
    required this.debtorName,
    required this.creditorUserId,
    required this.creditorName,
    required this.amountCents,
  });

  final String debtorUserId;
  final String debtorName;
  final String creditorUserId;
  final String creditorName;
  final int amountCents;
}

class _CounterpartyLedgerLine {
  const _CounterpartyLedgerLine({
    required this.fromName,
    required this.toName,
    required this.amountCents,
    required this.occurredAt,
  });

  final String fromName;
  final String toName;
  final int amountCents;
  final DateTime occurredAt;
}

class _SettleUpSummary {
  _SettleUpSummary({
    required this.counterpartyUserId,
    required this.counterpartyName,
    required this.netCents,
    required this.ledgerLines,
    required this.latestActivityAt,
  });

  final String counterpartyUserId;
  final String counterpartyName;
  int netCents;
  final List<_CounterpartyLedgerLine> ledgerLines;
  DateTime latestActivityAt;
}

enum _PaymentApprovalStatus { pending, confirmed, denied }

class _PayReceiveAmounts {
  const _PayReceiveAmounts({required this.toPay, required this.toReceive});

  final double toPay;
  final double toReceive;
}

class GroupSettleUpIntent {
  const GroupSettleUpIntent({required this.groupId, required this.counterpartyUserId});

  final String groupId;
  final String counterpartyUserId;
}

class _SettleMember {
  _SettleMember({
    required this.name,
    required this.balance,
    this.upiId,
  });

  final String name;
  double balance;
  final String? upiId;
}

final _fakeTransactions = [
  _GroupTransaction(
    sortKey: DateTime.utc(2026, 4, 4, 9, 0),
    date: 'Apr 04',
    title: 'Grocery',
    subtitle: 'You paid',
    amount: 20.50,
    isCredit: false,
    icon: Icons.shopping_bag_outlined,
  ),
  _GroupTransaction(
    sortKey: DateTime.utc(2026, 5, 2, 9, 0),
    date: 'May 02',
    title: 'Train refund price',
    subtitle: 'You lent',
    amount: 1600.00,
    isCredit: true,
    icon: Icons.train,
  ),
  _GroupTransaction(
    sortKey: DateTime.utc(2026, 5, 11, 9, 0),
    date: 'May 11',
    title: 'Dinner',
    subtitle: 'You paid',
    amount: 430.00,
    isCredit: false,
    icon: Icons.restaurant_outlined,
  ),
  _GroupTransaction(
    sortKey: DateTime.utc(2026, 5, 23, 9, 0),
    date: 'May 23',
    title: 'Taxi share',
    subtitle: 'You paid',
    amount: 35.20,
    isCredit: false,
    icon: Icons.directions_car_outlined,
  ),
  _GroupTransaction(
    sortKey: DateTime.utc(2026, 6, 1, 9, 0),
    date: 'Jun 01',
    title: 'Movie night',
    subtitle: 'You lent',
    amount: 220.00,
    isCredit: true,
    icon: Icons.movie_outlined,
  ),
];

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  static GroupSettleUpIntent? _pendingSettleUpIntent;
  static String? _pendingGroupPopupId;

  static void setPendingSettleUpIntent({
    required String groupId,
    required String counterpartyUserId,
  }) {
    _pendingSettleUpIntent = GroupSettleUpIntent(
      groupId: groupId,
      counterpartyUserId: counterpartyUserId,
    );
  }

  static GroupSettleUpIntent? takePendingSettleUpIntent() {
    final intent = _pendingSettleUpIntent;
    _pendingSettleUpIntent = null;
    return intent;
  }

  static void setPendingGroupPopup({required String groupId}) {
    _pendingGroupPopupId = groupId;
  }

  static String? takePendingGroupPopup() {
    final groupId = _pendingGroupPopupId;
    _pendingGroupPopupId = null;
    return groupId;
  }

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  static List<GroupSummary>? _cachedGroups;
  static List<GroupInvitation>? _cachedInvitations;

  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _inviteEmailController = TextEditingController();

  StreamSubscription<Uri>? _deepLinkSubscription;

  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _loadError;
  List<GroupSummary> _groups = <GroupSummary>[];
  List<GroupInvitation> _pendingInvitations = <GroupInvitation>[];
  final Map<String, List<_GroupTransaction>> _groupPreviewTransactions = {};
  AnimationController? _fabEntranceController;

  User? get _currentUser => _client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _ensureFabController();

    if (_cachedGroups != null || _cachedInvitations != null) {
      try {
        _groups = List<GroupSummary>.from(_cachedGroups ?? <GroupSummary>[]);
        _pendingInvitations =
            List<GroupInvitation>.from(_cachedInvitations ?? <GroupInvitation>[]);
        _isLoading = false;
        _hasLoadedOnce = true;
      } catch (_) {
        // Hot reload can leave stale cached model objects after shape changes.
        _cachedGroups = null;
        _cachedInvitations = null;
      }
    }

    _listenForPaymentCallbacks();
    _loadData();
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _deepLinkSubscription?.cancel();
    _fabEntranceController?.dispose();
    super.dispose();
  }

  void _ensureFabController() {
    _fabEntranceController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !(_fabEntranceController?.isAnimating ?? false)) {
        _fabEntranceController?.forward(from: 0);
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  void _listenForPaymentCallbacks() {
    final appLinks = AppLinks();
    _deepLinkSubscription = appLinks.uriLinkStream.listen((uri) async {
      await _handleIncomingUri(uri);
    });
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (uri.scheme != 'splitease' || uri.host != 'payment-callback') {
      return;
    }

    final settlementId = uri.queryParameters['settlement_id'] ?? uri.queryParameters['tr'];
    if (settlementId == null || settlementId.isEmpty) {
      return;
    }

    final statusRaw = (uri.queryParameters['Status'] ??
            uri.queryParameters['status'] ??
            uri.queryParameters['txnStatus'] ??
            '')
        .toUpperCase();

    final upiTxnRef = uri.queryParameters['ApprovalRefNo'] ??
        uri.queryParameters['txnRef'] ??
        uri.queryParameters['txnId'];

    final status = statusRaw == 'SUCCESS' ? 'completed' : 'failed';
    await _updateSettlementStatus(settlementId, status, upiTxnRef: upiTxnRef);

    if (!mounted) {
      return;
    }

    _showMessage(
      status == 'completed'
          ? 'UPI payment confirmed and settlement updated.'
          : 'UPI payment failed/cancelled.',
    );
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final user = _currentUser;
      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _groups = <GroupSummary>[];
          _pendingInvitations = <GroupInvitation>[];
          _groupPreviewTransactions.clear();
          _isLoading = false;
          _hasLoadedOnce = true;
          _cachedGroups = List<GroupSummary>.from(_groups);
          _cachedInvitations = List<GroupInvitation>.from(_pendingInvitations);
        });
        return;
      }

      final groups = await _fetchGroupsForUser(user.id);
      final invitations = await _fetchPendingInvitations(user.email);

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = groups;
        _pendingInvitations = invitations;
        _isLoading = false;
        _hasLoadedOnce = true;
        _cachedGroups = List<GroupSummary>.from(_groups);
        _cachedInvitations = List<GroupInvitation>.from(_pendingInvitations);
      });

      if (!_tryOpenPendingGroupPopup(groups)) {
        _tryOpenPendingSettleUpIntent(groups);
      }
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
        _loadError = 'Could not load groups (${error.message}).';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
        _loadError = 'Unable to load groups right now.';
      });
    }
  }

  bool _tryOpenPendingGroupPopup(List<GroupSummary> groups) {
    final pendingGroupId = GroupsScreen.takePendingGroupPopup();
    if (pendingGroupId == null || pendingGroupId.isEmpty) {
      return false;
    }

    GroupSummary? targetGroup;
    for (final group in groups) {
      if (group.id == pendingGroupId) {
        targetGroup = group;
        break;
      }
    }

    if (targetGroup == null) {
      _showMessage('Requested group not found.');
      return false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _openGroupDetailPopup(targetGroup!);
    });

    return true;
  }

  void _tryOpenPendingSettleUpIntent(List<GroupSummary> groups) {
    final intent = GroupsScreen.takePendingSettleUpIntent();
    if (intent == null) {
      return;
    }

    GroupSummary? targetGroup;
    for (final group in groups) {
      if (group.id == intent.groupId) {
        targetGroup = group;
        break;
      }
    }

    if (targetGroup == null) {
      _showMessage('Requested group not found.');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _openGroupDetailPopup(
        targetGroup!,
        initialSection: 'settleup',
        focusCounterpartyUserId: intent.counterpartyUserId,
      );
    });
  }

  Future<List<GroupSummary>> _fetchGroupsForUser(String userId) async {
    final memberships = await _client
        .from('group_members')
        .select('group_id,balance')
        .eq('user_id', userId) as List<dynamic>;

    final groupIds = memberships
        .map((row) => row['group_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (groupIds.isEmpty) {
      return <GroupSummary>[];
    }

    final fallbackBalanceByGroupId = <String, double>{};
    for (final row in memberships) {
      final groupId = row['group_id']?.toString() ?? '';
      if (groupId.isEmpty) {
        continue;
      }
      fallbackBalanceByGroupId[groupId] = _asDouble(row['balance']);
    }

    final payReceiveByGroupId = await _computePayReceiveByGroup(
      userId: userId,
      groupIds: groupIds,
      fallbackBalanceByGroupId: fallbackBalanceByGroupId,
    );

    final groupRows = await _client
        .from('groups')
        .select(
          'id,name,icon,created_by,created_at,total_expenses,total_owed,balance,settlement_status',
        )
        .inFilter('id', groupIds) as List<dynamic>;

    final memberCounts = await _fetchMemberCounts(groupIds);
    final creatorNames = await _fetchCreatorNames(groupIds);

    final summaries = <GroupSummary>[];
    for (final row in groupRows) {
      final groupId = row['id']?.toString() ?? '';
      if (groupId.isEmpty) {
        continue;
      }

      summaries.add(
        GroupSummary(
          id: groupId,
          name: row['name']?.toString() ?? 'Unnamed Group',
          icon: row['icon']?.toString() ?? 'group',
          createdByUserId: row['created_by']?.toString() ?? '',
          createdByName: _creatorNameFor(row, creatorNames),
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
          totalExpenses: _asDouble(row['total_expenses']),
          totalOwed: _asDouble(row['total_owed']),
          balance: (payReceiveByGroupId[groupId]?.toReceive ?? 0) -
              (payReceiveByGroupId[groupId]?.toPay ?? 0),
          toPayAmount: payReceiveByGroupId[groupId]?.toPay ?? 0,
          toReceiveAmount: payReceiveByGroupId[groupId]?.toReceive ?? 0,
          settlementStatus: row['settlement_status']?.toString(),
          memberCount: memberCounts[groupId] ?? 0,
        ),
      );
    }

    summaries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return summaries;
  }

  Future<Map<String, _PayReceiveAmounts>> _computePayReceiveByGroup({
    required String userId,
    required List<String> groupIds,
    required Map<String, double> fallbackBalanceByGroupId,
  }) async {
    final rows = await _client
        .from('group_settlements')
        .select('group_id,payer_user_id,receiver_user_id,amount,method,status')
        .inFilter('group_id', groupIds)
        .eq('method', 'split')
        .eq('status', 'pending') as List<dynamic>;

    final obligationsByGroup = <String, List<SettlementTransfer>>{};
    for (final row in rows) {
      final groupId = row['group_id']?.toString() ?? '';
      final payerUserId = row['payer_user_id']?.toString() ?? '';
      final receiverUserId = row['receiver_user_id']?.toString() ?? '';
      final amount = _asDouble(row['amount']);
      if (groupId.isEmpty || payerUserId.isEmpty || receiverUserId.isEmpty || amount <= 0) {
        continue;
      }

      obligationsByGroup.putIfAbsent(groupId, () => <SettlementTransfer>[]).add(
            SettlementTransfer(
              payerUserId: payerUserId,
              payeeUserId: receiverUserId,
              amountCents: (amount * 100).round(),
            ),
          );
    }

    final results = <String, _PayReceiveAmounts>{};
    for (final groupId in groupIds) {
      final obligations = obligationsByGroup[groupId] ?? <SettlementTransfer>[];

      if (obligations.isNotEmpty) {
        final minimized = computeMinimumSettlements(obligations: obligations);
        var toPay = 0.0;
        var toReceive = 0.0;

        for (final transfer in minimized) {
          if (transfer.payerUserId == userId) {
            toPay += transfer.amountCents / 100;
          }
          if (transfer.payeeUserId == userId) {
            toReceive += transfer.amountCents / 100;
          }
        }

        results[groupId] = _PayReceiveAmounts(toPay: toPay, toReceive: toReceive);
      } else {
        final fallback = fallbackBalanceByGroupId[groupId] ?? 0;
        results[groupId] = _PayReceiveAmounts(
          toPay: fallback < 0 ? -fallback : 0,
          toReceive: fallback > 0 ? fallback : 0,
        );
      }
    }

    return results;
  }

  Future<Map<String, String>> _fetchCreatorNames(List<String> groupIds) async {
    final rows = await _client
        .from('group_members')
        .select('group_id,user_id,display_name')
        .inFilter('group_id', groupIds) as List<dynamic>;

    final namesByGroupAndUser = <String, String>{};
    for (final row in rows) {
      final groupId = row['group_id']?.toString() ?? '';
      final userId = row['user_id']?.toString() ?? '';
      final displayName = row['display_name']?.toString().trim() ?? '';
      if (groupId.isEmpty || userId.isEmpty || displayName.isEmpty) {
        continue;
      }
      namesByGroupAndUser['$groupId|$userId'] = displayName;
    }

    return namesByGroupAndUser;
  }

  String _creatorNameFor(Map<String, dynamic> row, Map<String, String> creatorNames) {
    final groupId = row['id']?.toString() ?? '';
    final creatorId = row['created_by']?.toString() ?? '';
    final currentUser = _currentUser;

    if (currentUser != null && creatorId == currentUser.id) {
      return _currentUserPreferredName(currentUser);
    }

    final name = creatorNames['$groupId|$creatorId'];
    if (name != null && name.isNotEmpty) {
      return _friendlyNameFromDisplayValue(name);
    }

    if (creatorId.isEmpty) {
      return 'Unknown';
    }

    return creatorId.length <= 10 ? creatorId : creatorId.substring(0, 10);
  }

  String _currentUserPreferredName(User user) {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final candidates = [
      metadata['full_name']?.toString(),
      metadata['name']?.toString(),
      metadata['display_name']?.toString(),
      metadata['preferred_username']?.toString(),
      metadata['user_name']?.toString(),
    ];

    for (final candidate in candidates) {
      final normalized = _friendlyNameFromDisplayValue(candidate);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    final emailName = _friendlyNameFromDisplayValue(user.email);
    return emailName.isEmpty ? 'You' : emailName;
  }

  String _friendlyNameFromDisplayValue(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    // If display value is an email, show only the username part.
    final username = raw.contains('@') ? raw.split('@').first : raw;
    if (username.isEmpty) {
      return '';
    }

    final cleaned = username.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) {
      return username;
    }

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .toList();

    return words.isEmpty ? username : words.join(' ');
  }

  Future<Map<String, int>> _fetchMemberCounts(List<String> groupIds) async {
    final counts = <String, int>{};
    final rows = await _client
        .from('group_members')
        .select('group_id')
        .inFilter('group_id', groupIds) as List<dynamic>;

    for (final row in rows) {
      final groupId = row['group_id']?.toString() ?? '';
      if (groupId.isEmpty) {
        continue;
      }
      counts[groupId] = (counts[groupId] ?? 0) + 1;
    }

    return counts;
  }

  Future<List<GroupInvitation>> _fetchPendingInvitations(String? email) async {
    if (email == null || email.isEmpty) {
      return <GroupInvitation>[];
    }

    final rows = await _client
        .from('group_invitations')
        .select(
          'id,group_id,invitee_email,status,groups(name),inviter_name,invitee_name,invitee_upi,created_at',
        )
        .eq('invitee_email', email)
        .eq('status', 'pending')
        .order('created_at', ascending: false) as List<dynamic>;

    return rows
        .map(
          (row) => GroupInvitation(
            id: row['id']?.toString() ?? '',
            groupId: row['group_id']?.toString() ?? '',
            groupName: (row['groups'] as Map<String, dynamic>?)?['name']?.toString() ??
                'Unknown Group',
            inviterName: row['inviter_name']?.toString() ?? 'Group admin',
            inviteeEmail: row['invitee_email']?.toString() ?? '',
            inviteeName: row['invitee_name']?.toString(),
            inviteeUpi: row['invitee_upi']?.toString(),
            status: row['status']?.toString() ?? 'pending',
          ),
        )
        .where((invite) => invite.id.isNotEmpty && invite.groupId.isNotEmpty)
        .toList();
  }

  Future<GroupDetailsData> _fetchGroupDetails(GroupSummary group) async {
    final membersRows = await _client
        .from('group_members')
        .select('user_id,balance,status,display_name,upi_id')
        .eq('group_id', group.id) as List<dynamic>;

    final memberBalances = membersRows
        .map(
          (row) => GroupMemberBalance(
            userId: row['user_id']?.toString() ?? '',
            memberName: row['display_name']?.toString() ??
                'Member ${_memberSuffix(row['user_id']?.toString())}',
            balance: _asDouble(row['balance']),
            status: row['status']?.toString() ?? _memberStatus(_asDouble(row['balance'])),
            upiId: row['upi_id']?.toString(),
          ),
        )
        .where((member) => member.userId.isNotEmpty)
        .toList();

    final expenseRows = await _client
        .from('group_expenses')
      .select('description,amount,paid_by_name,expense_date,owes_summary,bill_image_url,created_at')
        .eq('group_id', group.id)
      .order('created_at', ascending: false) as List<dynamic>;

    final expenses = expenseRows
        .map(
          (row) => GroupExpense(
            description: row['description']?.toString() ?? 'Expense',
            amount: _asDouble(row['amount']),
            paidBy: row['paid_by_name']?.toString() ?? 'Unknown',
            date: DateTime.tryParse(row['expense_date']?.toString() ?? '') ?? DateTime.now(),
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
                DateTime.tryParse(row['expense_date']?.toString() ?? '') ??
                DateTime.now(),
            owesWhom: row['owes_summary']?.toString() ?? 'Split equally',
            billImageUrl: row['bill_image_url']?.toString(),
          ),
        )
        .toList();

    final nameByUserId = <String, String>{
      for (final member in memberBalances) member.userId: member.memberName,
    };
    final splitRows = await _client
        .from('group_settlements')
      .select('payer_user_id,receiver_user_id,amount,method,status,created_at')
        .eq('group_id', group.id)
        .eq('method', 'split')
      .eq('status', 'pending')
      .order('created_at', ascending: false) as List<dynamic>;

    final splitSettlementTransactions = splitRows
        .map((row) {
          final debtorUserId = row['payer_user_id']?.toString() ?? '';
          final creditorUserId = row['receiver_user_id']?.toString() ?? '';
          final amount = _asDouble(row['amount']);
          if (debtorUserId.isEmpty || creditorUserId.isEmpty || amount <= 0) {
            return null;
          }

          final debtorName = nameByUserId[debtorUserId] ?? 'Member';
          final creditorName = nameByUserId[creditorUserId] ?? 'Member';
          final isCredit = creditorUserId == _currentUser?.id;
          final createdAt =
              DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now();

          return _GroupTransaction(
            sortKey: createdAt,
            date: _formatDate(createdAt).split(',').first,
            title: '$debtorName pays $creditorName',
            subtitle: 'Saved split',
            amount: amount,
            isCredit: isCredit,
            icon: Icons.swap_horiz,
            settlementDetails: _SettlementTransactionDetails(
              debtorUserId: debtorUserId,
              debtorName: debtorName,
              creditorUserId: creditorUserId,
              creditorName: creditorName,
              amountCents: (amount * 100).round(),
            ),
          );
        })
        .whereType<_GroupTransaction>()
        .toList();

    final weekly = _sumSince(expenses, DateTime.now().subtract(const Duration(days: 7)));
    final monthly = _sumSince(expenses, DateTime.now().subtract(const Duration(days: 30)));

    return GroupDetailsData(
      members: memberBalances,
      expenses: expenses,
      splitSettlementTransactions: splitSettlementTransactions,
      weeklySpending: weekly,
      monthlySpending: monthly,
      totalTransactions: expenses.length + splitSettlementTransactions.length,
    );
  }

  List<_GroupTransaction> _buildExpenseTransactionsFromDb(List<GroupExpense> expenses) {
    return expenses
        .map(
          (expense) => _GroupTransaction(
            sortKey: expense.createdAt,
            date: _formatDate(expense.createdAt).split(',').first,
            title: expense.description,
            subtitle: 'Paid by ${expense.paidBy}',
            amount: expense.amount,
            isCredit: false,
            icon: Icons.receipt_long,
            expenseDetails: _ExpenseTransactionDetails(
              expenseName: expense.description,
              totalAmount: expense.amount,
              paidBy: <_PaidByLine>[
                _PaidByLine(memberName: expense.paidBy, amount: expense.amount),
              ],
              participants: <String>[],
            ),
          ),
        )
        .toList();
  }

  List<_GroupTransaction> _sortTransactionsNewestFirst(
    Iterable<_GroupTransaction> entries,
  ) {
    final sorted = List<_GroupTransaction>.from(entries);
    sorted.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return sorted;
  }

  Future<bool> _persistExpenseSplit({
    required GroupSummary group,
    required String expenseName,
    required List<_MemberOption> members,
    required Map<String, double> paidByUserId,
    required List<_GroupTransaction> computedTransactions,
  }) async {
    final user = _currentUser;
    if (user == null) {
      _showMessage('Please sign in again.');
      return false;
    }

    final totalAmount = paidByUserId.values.fold<double>(0, (sum, value) => sum + value);
    if (totalAmount <= 0) {
      _showMessage('Total paid amount must be greater than zero.');
      return false;
    }

    final paidMembers = members
        .where((member) => (paidByUserId[member.userId] ?? 0) > 0)
        .map((member) => member.displayName)
        .toList();

    final paidByName = paidMembers.isEmpty
        ? 'Unknown'
        : paidMembers.length == 1
            ? paidMembers.first
            : 'Multiple members';

    final splitLines = computedTransactions
        .map((tx) => tx.settlementDetails)
        .whereType<_SettlementTransactionDetails>()
        .map(
          (detail) => '${detail.debtorName} pays ${detail.creditorName} ${_money(detail.amountCents / 100)}',
        )
        .toList();

    final owesSummary = splitLines.isEmpty ? 'No split' : splitLines.join(' | ');

    String paidByUserIdForRow = user.id;
    var maxPaid = -1.0;
    for (final entry in paidByUserId.entries) {
      if (entry.value > maxPaid) {
        maxPaid = entry.value;
        paidByUserIdForRow = entry.key;
      }
    }

    final hasPaidByUser = members.any((member) => member.userId == paidByUserIdForRow);
    if (!hasPaidByUser) {
      paidByUserIdForRow = user.id;
    }

    final splitRows = computedTransactions
        .map((tx) => tx.settlementDetails)
        .whereType<_SettlementTransactionDetails>()
        .map(
          (detail) => <String, dynamic>{
            'debtor_user_id': detail.debtorUserId,
            'creditor_user_id': detail.creditorUserId,
            'amount': detail.amountCents / 100,
          },
        )
        .toList();

    try {
      await _client.rpc(
        'create_group_expense_with_splits',
        params: {
          '_group_id': group.id,
          '_description': expenseName,
          '_amount': totalAmount,
          '_paid_by_user_id': paidByUserIdForRow,
          '_paid_by_name': paidByName,
          '_owes_summary': owesSummary,
          '_split_rows': splitRows,
        },
      );

      return true;
    } on PostgrestException catch (error) {
      _showMessage(
        'Could not save expense (${error.message}). Run latest Supabase migration.',
      );
      return false;
    } catch (_) {
      _showMessage('Unable to save expense right now.');
      return false;
    }
  }

  Future<String?> _fetchMemberUpiId(String groupId, String userId) async {
    if (groupId.isEmpty || userId.isEmpty) {
      return null;
    }

    try {
      final row = await _client
          .from('group_members')
          .select('upi_id')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      final upiId = row?['upi_id']?.toString().trim();
      if (upiId == null || upiId.isEmpty) {
        return null;
      }
      return upiId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendPaymentConfirmationNotification({
    required String groupId,
    required String receiverUserId,
    required String receiverName,
    required double amount,
    required String method,
  }) async {
    final user = _currentUser;
    if (user == null || receiverUserId.isEmpty) {
      return;
    }

    final senderName = _currentUserPreferredName(user);
    final normalizedMethod = method.toLowerCase() == 'cash' ? 'cash' : 'upi';

    try {
      await _client.from('group_notifications').insert({
        'group_id': groupId,
        'sender_user_id': user.id,
        'sender_name': senderName,
        'receiver_user_id': receiverUserId,
        'receiver_name': receiverName,
        'category': 'payment_received_confirmation',
        'method': normalizedMethod,
        'amount': amount,
        'status': 'pending',
      });
    } catch (_) {
      // Keep payment flow uninterrupted if notification insertion fails.
    }
  }

  Future<bool> _sendPaymentRequestNotification({
    required String groupId,
    required String receiverUserId,
    required String receiverName,
    required double amount,
  }) async {
    final user = _currentUser;
    if (user == null || receiverUserId.isEmpty) {
      return false;
    }

    final senderName = _currentUserPreferredName(user);

    try {
      await _client.from('group_notifications').insert({
        'group_id': groupId,
        'sender_user_id': user.id,
        'sender_name': senderName,
        'receiver_user_id': receiverUserId,
        'receiver_name': receiverName,
        'category': 'payment_request',
        'method': 'request',
        'amount': amount,
        'status': 'pending',
      });
      return true;
    } catch (_) {
      // Keep UI responsive even if notification insert fails.
      return false;
    }
  }

  Future<Set<String>> _fetchPendingOutgoingPaymentRequests({
    required String groupId,
    required String senderUserId,
  }) async {
    if (groupId.isEmpty || senderUserId.isEmpty) {
      return <String>{};
    }

    try {
      final rows = await _client
          .from('group_notifications')
          .select('sender_user_id,receiver_user_id,status,created_at')
          .eq('group_id', groupId)
          .eq('category', 'payment_request')
          .eq('sender_user_id', senderUserId)
          .order('created_at', ascending: false) as List<dynamic>;

      final latestStatusByPair = <String, String>{};
      for (final row in rows) {
        final senderId = row['sender_user_id']?.toString() ?? '';
        final receiverId = row['receiver_user_id']?.toString() ?? '';
        final status = row['status']?.toString().toLowerCase() ?? 'pending';
        if (senderId.isEmpty || receiverId.isEmpty) {
          continue;
        }

        final key = '$senderId|$receiverId';
        if (latestStatusByPair.containsKey(key)) {
          continue;
        }
        latestStatusByPair[key] = status;
      }

      return latestStatusByPair.entries
          .where((entry) => entry.value == 'pending')
          .map((entry) => entry.key)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<Map<String, _PaymentApprovalStatus>> _fetchLatestPaymentApprovals(
    String groupId,
  ) async {
    if (groupId.isEmpty) {
      return <String, _PaymentApprovalStatus>{};
    }

    try {
      final rows = await _client
          .from('group_notifications')
          .select('sender_user_id,receiver_user_id,status,created_at')
          .eq('group_id', groupId)
          .eq('category', 'payment_received_confirmation')
          .order('created_at', ascending: false) as List<dynamic>;

      final approvals = <String, _PaymentApprovalStatus>{};
      for (final row in rows) {
        final senderUserId = row['sender_user_id']?.toString() ?? '';
        final receiverUserId = row['receiver_user_id']?.toString() ?? '';
        final status = row['status']?.toString().toLowerCase() ?? 'pending';
        if (senderUserId.isEmpty || receiverUserId.isEmpty) {
          continue;
        }

        final key = '$senderUserId|$receiverUserId';
        if (approvals.containsKey(key)) {
          continue;
        }

        approvals[key] = switch (status) {
          'confirmed' => _PaymentApprovalStatus.confirmed,
          'denied' => _PaymentApprovalStatus.denied,
          _ => _PaymentApprovalStatus.pending,
        };
      }

      return approvals;
    } catch (_) {
      return <String, _PaymentApprovalStatus>{};
    }
  }

  Future<void> _openGroupSectionPopup({
    required GroupSummary group,
    required String sectionTitle,
    required Widget Function(GroupDetailsData details) builder,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<GroupDetailsData>(
              future: _fetchGroupDetails(group),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 320,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return SizedBox(
                    height: 320,
                    child: Center(
                      child: Text(
                        'Could not load group details. Make sure group_expenses and group_members tables exist.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                final details = snapshot.data!;

                return SizedBox(
                  width: 640,
                  height: 560,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFD8ECFA),
                            child: Icon(
                              _GroupBar._iconFor(group.icon),
                              color: const Color(0xFF1D6CAB),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$sectionTitle - ${group.name}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: builder(details),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExpenseListPopup(GroupSummary group) {
    return _openGroupSectionPopup(
      group: group,
      sectionTitle: 'Expense List',
      builder: (details) => _ExpenseListCard(expenses: details.expenses),
    );
  }

  Future<void> _openMemberBalancePopup(GroupSummary group) {
    return _openGroupSectionPopup(
      group: group,
      sectionTitle: 'Member Balance List',
      builder: (details) => _MemberBalanceCard(
        members: details.members,
        currentUserId: _currentUser?.id,
        isOwner: group.createdByUserId == _currentUser?.id,
        onPay: (member) => _openPaymentPopup(group, member),
        onRemoveMember: (member) => _removeMemberFromGroup(group, member),
      ),
    );
  }

  Future<void> _openGroupActionsPopup(GroupSummary group) {
    return _openGroupSectionPopup(
      group: group,
      sectionTitle: 'Group Actions',
      builder: (_) => _ActionCard(
        onAddExpense: () => _openAddExpenseDialog(group),
        onAddMembers: () => _openAddMemberDialog(group),
      ),
    );
  }

  Future<void> _openGroupDetailPopup(
    GroupSummary group, {
    String initialSection = 'transactions',
    String? focusCounterpartyUserId,
  }) async {
    final youOwe = group.toPayAmount;
    final youAreOwed = group.toReceiveAmount;
    List<_GroupTransaction> persistedTransactions = <_GroupTransaction>[];
    var approvalByPair = <String, _PaymentApprovalStatus>{};
    var pendingRequestPairs = <String>{};
    final currentUserId = _currentUser?.id;

    try {
      final details = await _fetchGroupDetails(group);
      persistedTransactions = <_GroupTransaction>[
        ..._buildExpenseTransactionsFromDb(details.expenses),
        ...details.splitSettlementTransactions,
      ];
    } catch (_) {
      // Group popup will still open with current-session transactions.
    }

    approvalByPair = await _fetchLatestPaymentApprovals(group.id);
    if (currentUserId != null) {
      pendingRequestPairs = await _fetchPendingOutgoingPaymentRequests(
        groupId: group.id,
        senderUserId: currentUserId,
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.82;
        final maxWidth = MediaQuery.of(context).size.width * 0.92;
        final createdDate = _formatDate(group.createdAt);
        final localPreview = _groupPreviewTransactions[group.id] ?? <_GroupTransaction>[];
        var transactions = _sortTransactionsNewestFirst(
          persistedTransactions.isNotEmpty ? persistedTransactions : localPreview,
        );
        var selectedSection = initialSection;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              backgroundColor: Colors.white,
              child: SizedBox(
                height: maxHeight,
                width: maxWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Material(
                    color: Colors.white,
                    child: Stack(
                      children: [
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 84),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Stack(
                          children: [
                            Positioned(
                              right: 0,
                              child: IconButton(
                                padding: const EdgeInsets.all(12),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close, size: 22),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 30,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(28),
                                      onTap: () => _openMembersDirectoryPopup(group),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: const Color(0xFFD8ECFA),
                                            foregroundColor: const Color(0xFF1D6CAB),
                                            child: Icon(
                                              _GroupBar._iconFor(group.icon),
                                              size: 28,
                                            ),
                                          ),
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A4A8F),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.white, width: 1.5),
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.person, size: 18, color: Color(0xFF5A6E82)),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Created by ${group.createdByName}',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: const Color(0xFF5A6E82),
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.group, size: 18, color: Color(0xFF5A6E82)),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${group.memberCount} people',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: const Color(0xFF5A6E82),
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today, size: 18, color: Color(0xFF5A6E82)),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Created $createdDate',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: const Color(0xFF5A6E82),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: FloatingActionButton(
                                        heroTag: 'group-add-expense-${group.id}',
                                        backgroundColor: const Color(0xFF1A4A8F),
                                        foregroundColor: Colors.white,
                                        onPressed: () => _openAddExpenseDialog(
                                          group,
                                          onPreviewGenerated: (computedTransactions) {
                                            final existing = transactions;
                                            final merged = _sortTransactionsNewestFirst(<_GroupTransaction>[
                                              ...computedTransactions,
                                              ...existing,
                                            ]);

                                            setState(() {
                                              _groupPreviewTransactions[group.id] = merged;
                                            });
                                            setModalState(() {
                                              transactions = List<_GroupTransaction>.from(merged);
                                            });
                                          },
                                        ),
                                        child: const Icon(Icons.add),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Owe / Owed cards
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _BalanceCard(
                                label: 'To Pay',
                                amount: youOwe,
                                icon: Icons.arrow_upward,
                                iconBackground: const Color(0xFFFFE5E5),
                                iconColor: const Color(0xFFB33A2E),
                                amountColor: const Color(0xFFB33A2E),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BalanceCard(
                                label: 'To Receive',
                                amount: youAreOwed,
                                icon: Icons.arrow_downward,
                                iconBackground: const Color(0xFFE9F9EB),
                                iconColor: const Color(0xFF1B7D3A),
                                amountColor: const Color(0xFF1B7D3A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Section toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const SizedBox(
                                  width: double.infinity,
                                  child: Text('Transactions', textAlign: TextAlign.center),
                                ),
                                showCheckmark: false,
                                selected: selectedSection == 'transactions',
                                onSelected: (_) {
                                  setModalState(() {
                                    selectedSection = 'transactions';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const SizedBox(
                                  width: double.infinity,
                                  child: Text('Balances', textAlign: TextAlign.center),
                                ),
                                showCheckmark: false,
                                selected: selectedSection == 'balances',
                                onSelected: (_) {
                                  setModalState(() {
                                    selectedSection = 'balances';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const SizedBox(
                                  width: double.infinity,
                                  child: Text('Settle up', textAlign: TextAlign.center),
                                ),
                                showCheckmark: false,
                                selected: selectedSection == 'settleup',
                                onSelected: (_) {
                                  setModalState(() {
                                    selectedSection = 'settleup';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                          // Section content
                          Builder(
                            builder: (context) {
                              final expenseTransactions = transactions
                                  .where((item) => item.expenseDetails != null)
                                  .toList();
                              final balanceTransactions = transactions
                                  .where((item) => item.settlementDetails != null)
                                  .toList();

                              if (selectedSection == 'transactions') {
                                return _buildGroupSectionTransactions(
                                  items: expenseTransactions,
                                  emptyText: 'No expense entries yet. Tap + to add one.',
                                );
                              }

                              if (selectedSection == 'balances') {
                                return _buildGroupSectionTransactions(
                                  items: balanceTransactions,
                                  emptyText: 'No balance splits yet.',
                                  compactVisual: true,
                                );
                              }

                              return _buildInlineSettleUpSection(
                                group,
                                transactions,
                                approvalByPair: approvalByPair,
                                pendingRequestPairs: pendingRequestPairs,
                                focusCounterpartyUserId: focusCounterpartyUserId,
                                onApprovalStatusChanged: (payerUserId, payeeUserId, status) {
                                  setModalState(() {
                                    approvalByPair['$payerUserId|$payeeUserId'] = status;
                                  });
                                },
                                onRequestStatusChanged: (senderUserId, receiverUserId, isPending) {
                                  setModalState(() {
                                    final key = '$senderUserId|$receiverUserId';
                                    if (isPending) {
                                      pendingRequestPairs.add(key);
                                    } else {
                                      pendingRequestPairs.remove(key);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSettleUpPopup(GroupSummary group) async {
    final members = <_SettleMember>[
      _SettleMember(name: 'Ayaan K.', balance: -250.50),
      _SettleMember(name: 'Sneh', balance: 180.00),
      _SettleMember(name: 'Priya', balance: -45.20),
      _SettleMember(name: 'Raj', balance: 75.40),
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.9;
        final maxWidth = MediaQuery.of(context).size.width * 0.92;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          backgroundColor: Colors.transparent,
          child: SizedBox(
            height: maxHeight,
            width: maxWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Material(
                color: Colors.white,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Settle up',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Select a member to settle your balance',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFF5A6E82),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                padding: const EdgeInsets.all(12),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close, size: 22),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: members.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final owesMe = member.balance > 0;
                                final iOwe = member.balance < 0;
                                final amount = member.balance.abs();
                                final amountLabel = _money(amount);
                                final subtitle = owesMe
                                  ? 'To Receive'
                                  : iOwe
                                    ? 'To Pay'
                                    : 'Settled';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: const Color(0xFFD8ECFA),
                                            foregroundColor: const Color(0xFF1D6CAB),
                                            child: Text(
                                              member.name.isNotEmpty ? member.name[0] : '?',
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  member.name,
                                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitle,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: const Color(0xFF5A6E82),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                amountLabel,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                      color: owesMe
                                                          ? const Color(0xFF1B7D3A)
                                                          : iOwe
                                                              ? const Color(0xFFB33A2E)
                                                              : const Color(0xFF5C6470),
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${amount.toStringAsFixed(2)}',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: const Color(0xFF5A6E82),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          if (iOwe) ...[
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: () async {
                                                  Navigator.of(context).pop();

                                                  final recipientUpiId = member.upiId?.trim();
                                                  if (recipientUpiId == null || recipientUpiId.isEmpty) {
                                                    _showMessage(
                                                      'UPI ID is missing for ${member.name}.',
                                                    );
                                                    return;
                                                  }

                                                  final launched = await UpiDeepLink.launchUpiPayment(
                                                    receiverName: member.name,
                                                    amount: amount,
                                                    recipientUpiId: recipientUpiId,
                                                    note: 'SpliTease ${group.name}',
                                                  );

                                                  if (!mounted) {
                                                    return;
                                                  }

                                                  _showMessage(
                                                    launched
                                                        ? 'UPI app opened for ${member.name}.'
                                                        : 'Could not open UPI app on this device.',
                                                  );
                                                },
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  backgroundColor: const Color(0xFF1A4A8F),
                                                ),
                                                child: const Text(
                                                  'Pay by UPI',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _showMessage('Marked as paid by cash (stub).');
                                                },
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  backgroundColor: const Color(0xFF1A4A8F),
                                                ),
                                                child: const Text(
                                                  'Pay by cash',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ] else if (owesMe) ...[
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _showMessage('Request sent (stub).');
                                                },
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  backgroundColor: const Color(0xFF1A4A8F),
                                                ),
                                                child: const Text(
                                                  'Request',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: () {
                                                  setState(() {
                                                    member.balance = 0;
                                                  });
                                                  _showMessage('Waived amount for ${member.name}.');
                                                },
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  backgroundColor: const Color(0xFF1A4A8F),
                                                ),
                                                child: const Text(
                                                  'Waive',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: () {
                                                  _showMessage('Nothing to settle.');
                                                },
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  backgroundColor: const Color(0xFFB0BEC5),
                                                ),
                                                child: const Text(
                                                  'Settled',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPaymentPopup(GroupSummary group, GroupMemberBalance member) async {
    final amount = member.balance.abs();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settle Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Member: ${member.memberName}'),
              const SizedBox(height: 6),
              Text('Amount: ${_money(amount)}'),
              const SizedBox(height: 14),
              const Text('Choose settlement method:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _recordSettlement(
                  group.id,
                  member.userId,
                  amount,
                  method: 'self',
                  status: 'completed',
                );
              },
              child: const Text('Pay Yourself'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _startUpiPayment(group, member, amount);
              },
              child: const Text('Pay Using UPI'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startUpiPayment(
    GroupSummary group,
    GroupMemberBalance receiver,
    double amount,
  ) async {
    final recipientUpiId = receiver.upiId?.trim();
    if (recipientUpiId == null || recipientUpiId.isEmpty) {
      _showMessage('UPI ID is missing for ${receiver.memberName}.');
      return;
    }

    final settlementId = await _recordSettlement(
      group.id,
      receiver.userId,
      amount,
      method: 'upi',
      status: 'pending',
    );

    if (settlementId == null) {
      return;
    }

    final callbackUri = Uri(
      scheme: 'splitease',
      host: 'payment-callback',
      queryParameters: <String, String>{'settlement_id': settlementId},
    ).toString();

    final launched = await UpiDeepLink.launchUpiPayment(
      receiverName: receiver.memberName,
      amount: amount,
      recipientUpiId: recipientUpiId,
      note: 'SpliTease ${group.name}',
      transactionRef: settlementId,
      callbackUrl: callbackUri,
    );
    if (!launched) {
      await _updateSettlementStatus(settlementId, 'failed');
      _showMessage('Could not open UPI app on this device.');
      return;
    }

    _showMessage('UPI opened. Complete payment and return to app for auto-settlement.');
  }

  Future<String?> _recordSettlement(
    String groupId,
    String memberUserId,
    double amount, {
    required String method,
    required String status,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return null;
    }

    try {
      final result = await _client
          .from('group_settlements')
          .insert({
            'group_id': groupId,
            'payer_user_id': user.id,
            'receiver_user_id': memberUserId,
            'amount': amount,
            'method': method,
            'status': status,
            'settled_at': status == 'completed' ? DateTime.now().toIso8601String() : null,
          })
          .select('id')
          .single();

      if (!mounted) {
        return null;
      }

      if (status == 'completed') {
        _showMessage('Payment marked as settled.');
        await _loadData();
      }

      return result['id']?.toString();
    } on PostgrestException catch (error) {
      if (mounted) {
        _showMessage('Could not save settlement (${error.message}).');
      }
      return null;
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to record settlement right now.');
      }
      return null;
    }
  }

  Future<void> _updateSettlementStatus(
    String settlementId,
    String status, {
    String? upiTxnRef,
  }) async {
    try {
      await _client
          .from('group_settlements')
          .update({
            'status': status,
            'upi_txn_ref': upiTxnRef,
            'settled_at': status == 'completed' ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', settlementId);
    } catch (_) {
      // Do not interrupt app flow if callback update fails.
    }
  }

  Future<void> _openCreateGroupDialog() async {
    final nameController = TextEditingController();
    String selectedIcon = 'group';
    final groupIcons = <MapEntry<String, String>>[
      const MapEntry('group', 'Group'),
      const MapEntry('food', 'Food'),
      const MapEntry('flight', 'Trip'),
      const MapEntry('home', 'Home'),
      const MapEntry('sports', 'Sports'),
    ];

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Create group',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('New Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedIcon,
                    items: groupIcons
                        .map(
                          (icon) => DropdownMenuItem<String>(
                            value: icon.key,
                            child: Row(
                              children: [
                                Icon(_GroupBar._iconFor(icon.key), size: 18),
                                const SizedBox(width: 8),
                                Text(icon.value),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedIcon = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Group icon'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      _showMessage('Group name is required.');
                      return;
                    }

                    Navigator.of(this.context).pop();
                    await _createGroup(name, selectedIcon);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _createGroup(String name, String icon) async {
    try {
      await _client.rpc('create_group_with_owner', params: {
        '_name': name,
        '_icon': icon,
      });
      _showMessage('Group created.');
      await _loadData();
    } on PostgrestException catch (error) {
      _showMessage(
        'Could not create group (${error.message}). Run SQL migration first.',
      );
    } catch (_) {
      _showMessage('Unable to create group right now.');
    }
  }

  Future<void> _openAddExpenseDialog(
    GroupSummary group, {
    void Function(List<_GroupTransaction> transactions)? onPreviewGenerated,
  }) async {
    final expenseNameController = TextEditingController();

    try {
      final rows = await _client
          .from('group_members')
          .select('user_id,display_name')
          .eq('group_id', group.id) as List<dynamic>;

      final members = rows
          .map(
            (row) => _MemberOption(
              userId: row['user_id']?.toString() ?? '',
              displayName: row['display_name']?.toString() ?? 'Member',
            ),
          )
          .where((member) => member.userId.isNotEmpty)
          .toList();

      if (members.isEmpty) {
        _showMessage('No members found in this group.');
        return;
      }

      final paidControllers = <String, TextEditingController>{
        for (final member in members) member.userId: TextEditingController(text: '0'),
      };
      final includeMap = <String, bool>{
        for (final member in members) member.userId: true,
      };
      var splitMode = 'equally';

      double totalPaid() {
        var total = 0.0;
        for (final controller in paidControllers.values) {
          total += double.tryParse(controller.text.trim()) ?? 0;
        }
        return total;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          final maxHeight = MediaQuery.of(context).size.height * 0.82;
          final maxWidth = MediaQuery.of(context).size.width * 0.92;

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(36),
                ),
                child: SizedBox(
                  width: maxWidth,
                  height: maxHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Material(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Add Expense - ${group.name}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: expenseNameController,
                                  decoration: const InputDecoration(labelText: 'Expense name'),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Amount paid by each member',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                ...members.map(
                                  (member) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(member.displayName)),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 120,
                                          child: TextField(
                                            controller: paidControllers[member.userId],
                                            keyboardType: const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                            onChanged: (_) => setModalState(() {}),
                                            decoration: const InputDecoration(
                                              labelText: 'Paid',
                                              prefixText: '₹',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total expense: ${_money(totalPaid())}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A4A8F),
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'How to split?',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: const Text('Equally'),
                                      selected: splitMode == 'equally',
                                      onSelected: (_) {
                                        setModalState(() {
                                          splitMode = 'equally';
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: const Text('Unequally'),
                                      selected: splitMode == 'unequally',
                                      onSelected: (_) {
                                        setModalState(() {
                                          splitMode = 'unequally';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (splitMode == 'equally') ...[
                                  Text(
                                    'Participants:',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...members.map(
                                    (member) => CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(member.displayName),
                                      value: includeMap[member.userId] ?? true,
                                      onChanged: (value) {
                                        setModalState(() {
                                          includeMap[member.userId] = value ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                ] else ...[
                                  UnquallyScreen(
                                    memberNames: members
                                        .map((member) => member.displayName)
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () async {
                                final expenseName = expenseNameController.text.trim();
                                if (expenseName.isEmpty) {
                                  _showMessage('Expense name is required.');
                                  return;
                                }

                                if (splitMode == 'equally') {
                                  final participantCount =
                                      includeMap.values.where((included) => included).length;
                                  if (participantCount == 0) {
                                    _showMessage('Select at least one participant.');
                                    return;
                                  }
                                }

                                final paidByUserId = <String, double>{
                                  for (final member in members)
                                    member.userId: double.tryParse(
                                          paidControllers[member.userId]?.text.trim() ?? '0',
                                        ) ??
                                        0,
                                };

                                final settlements = _buildSettlementPreviewTransactions(
                                  expenseName: expenseName,
                                  members: members,
                                  paidByUserId: paidByUserId,
                                  includeMap: includeMap,
                                  currentUserId: _currentUser?.id,
                                );

                                final saved = await _persistExpenseSplit(
                                  group: group,
                                  expenseName: expenseName,
                                  members: members,
                                  paidByUserId: paidByUserId,
                                  computedTransactions: settlements,
                                );
                                if (!saved) {
                                  return;
                                }

                                onPreviewGenerated?.call(settlements);
                                if (!mounted) {
                                  return;
                                }
                                Navigator.of(context).pop();
                                _showMessage('Expense saved and split generated.');
                                await _loadData();
                              },
                              child: const Text('Continue'),
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
            },
          );
        },
      );
    } on PostgrestException catch (error) {
      _showMessage('Could not open add expense form (${error.message}).');
    } catch (_) {
      _showMessage('Unable to add expense right now.');
    }
  }

  Future<void> _openExpenseTransactionDetailsDialog(
    _ExpenseTransactionDetails details,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(details.expenseName),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total: ${_money(details.totalAmount)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Who paid what',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...details.paidBy.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.memberName)),
                          Text(_money(line.amount)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Participants',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: details.participants
                        .map(
                          (name) => Chip(
                            label: Text(name),
                            backgroundColor: const Color(0xFFE9F4FF),
                          ),
                        )
                        .toList(),
                  ),
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

  Widget _buildGroupSectionTransactions({
    required List<_GroupTransaction> items,
    required String emptyText,
    bool compactVisual = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: items.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                emptyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5A6E82),
                    ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final transaction = items[index];
                return _TransactionRow(
                  transaction: transaction,
                  compactVisual: compactVisual,
                  onTap: transaction.expenseDetails == null
                      ? null
                      : () => _openExpenseTransactionDetailsDialog(
                            transaction.expenseDetails!,
                          ),
                );
              },
            ),
    );
  }

  Widget _buildInlineSettleUpSection(
    GroupSummary group,
    List<_GroupTransaction> transactions,
    {
      required Map<String, _PaymentApprovalStatus> approvalByPair,
      required Set<String> pendingRequestPairs,
      String? focusCounterpartyUserId,
      required void Function(
        String payerUserId,
        String payeeUserId,
        _PaymentApprovalStatus status,
      )
      onApprovalStatusChanged,
      required void Function(String senderUserId, String receiverUserId, bool isPending)
      onRequestStatusChanged,
    }
  ) {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) {
      return const SizedBox.shrink();
    }

    final summaries = _buildSettleUpSummaries(
      transactions: transactions,
      currentUserId: currentUserId,
    );
    final orderedSummaries = List<_SettleUpSummary>.from(summaries);
    if (focusCounterpartyUserId != null && focusCounterpartyUserId.isNotEmpty) {
      orderedSummaries.sort((a, b) {
        final aFocused = a.counterpartyUserId == focusCounterpartyUserId;
        final bFocused = b.counterpartyUserId == focusCounterpartyUserId;
        if (aFocused == bFocused) {
          return 0;
        }
        return aFocused ? -1 : 1;
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settle up',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a member to settle your balance',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5A6E82),
                ),
          ),
          const SizedBox(height: 10),
          if (orderedSummaries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'No pending settlements yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5A6E82),
                    ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orderedSummaries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final summary = orderedSummaries[index];
                final iOwe = summary.netCents > 0;
                final owesMe = summary.netCents < 0;
                final amount = (summary.netCents.abs()) / 100;
                final payerUserId = iOwe ? currentUserId : summary.counterpartyUserId;
                final payeeUserId = iOwe ? summary.counterpartyUserId : currentUserId;
                final approvalKey = '$payerUserId|$payeeUserId';
                final approvalStatus = approvalByPair[approvalKey];
                final requestKey = '$currentUserId|${summary.counterpartyUserId}';
                final isRequestPending = pendingRequestPairs.contains(requestKey);
                final isPaymentDone = approvalStatus == _PaymentApprovalStatus.confirmed;
                final isPendingApproval = approvalStatus == _PaymentApprovalStatus.pending;
                final isApprovalDenied = approvalStatus == _PaymentApprovalStatus.denied;
                final subtitle = owesMe
                  ? 'To Receive'
                  : iOwe
                    ? 'To Pay'
                    : 'Settled';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(24),
                  border: summary.counterpartyUserId == focusCounterpartyUserId
                      ? Border.all(color: const Color(0xFF1A4A8F), width: 1.4)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A4A8F).withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFD8ECFA),
                          foregroundColor: const Color(0xFF1D6CAB),
                          child: Text(
                            summary.counterpartyName.isNotEmpty
                                ? summary.counterpartyName[0]
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _openCounterpartyLedgerDialog(summary),
                                child: Text(
                                  summary.counterpartyName,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF5A6E82),
                                    ),
                              ),
                              if (isPendingApproval) ...[
                                const SizedBox(height: 3),
                                Text(
                                  iOwe ? 'Pending approval' : 'Pending your approval',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFFAF7A00),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ] else if (isApprovalDenied) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Approval denied',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFFB33A2E),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ] else if (isPaymentDone) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Payment done',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF1B7D3A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 108,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _money(amount),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: owesMe
                                          ? const Color(0xFF1B7D3A)
                                          : iOwe
                                              ? const Color(0xFFB33A2E)
                                              : const Color(0xFF5C6470),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (iOwe && !isPaymentDone && !isPendingApproval) ...[
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final recipientUpiId = await _fetchMemberUpiId(
                                  group.id,
                                  summary.counterpartyUserId,
                                );
                                if (recipientUpiId == null || recipientUpiId.isEmpty) {
                                  _showMessage(
                                    'UPI ID is missing for ${summary.counterpartyName}.',
                                  );
                                  return;
                                }

                                final launched = await UpiDeepLink.launchUpiPayment(
                                  receiverName: summary.counterpartyName,
                                  amount: amount,
                                  recipientUpiId: recipientUpiId,
                                  note: 'SpliTease ${group.name}',
                                );

                                if (!mounted) {
                                  return;
                                }

                                if (launched) {
                                  await _sendPaymentConfirmationNotification(
                                    groupId: group.id,
                                    receiverUserId: summary.counterpartyUserId,
                                    receiverName: summary.counterpartyName,
                                    amount: amount,
                                    method: 'upi',
                                  );
                                  onApprovalStatusChanged(
                                    currentUserId,
                                    summary.counterpartyUserId,
                                    _PaymentApprovalStatus.pending,
                                  );
                                }

                                _showMessage(
                                  launched
                                      ? 'UPI app opened for ${summary.counterpartyName}.'
                                      : 'Could not open UPI app on this device.',
                                );
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(0xFF1A4A8F),
                              ),
                              child: const Text(
                                'Pay by UPI',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await _sendPaymentConfirmationNotification(
                                  groupId: group.id,
                                  receiverUserId: summary.counterpartyUserId,
                                  receiverName: summary.counterpartyName,
                                  amount: amount,
                                  method: 'cash',
                                );
                                onApprovalStatusChanged(
                                  currentUserId,
                                  summary.counterpartyUserId,
                                  _PaymentApprovalStatus.pending,
                                );
                                _showMessage(
                                  'Cash payment marked. Confirmation request sent to ${summary.counterpartyName}.',
                                );
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(0xFF1A4A8F),
                              ),
                              child: const Text(
                                'Pay by cash',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ] else if (iOwe && isPendingApproval) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: null,
                              child: const Text('Pending approval'),
                            ),
                          ),
                        ] else if (iOwe && isPaymentDone) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: null,
                              child: const Text('Payment done'),
                            ),
                          ),
                        ] else if (owesMe && !isPaymentDone && !isPendingApproval) ...[
                          Expanded(
                            child: FilledButton(
                              onPressed: isRequestPending
                                  ? null
                                  : () async {
                                      final sent = await _sendPaymentRequestNotification(
                                        groupId: group.id,
                                        receiverUserId: summary.counterpartyUserId,
                                        receiverName: summary.counterpartyName,
                                        amount: amount,
                                      );

                                      if (sent) {
                                        onRequestStatusChanged(
                                          currentUserId,
                                          summary.counterpartyUserId,
                                          true,
                                        );
                                        _showMessage(
                                          'Payment request sent to ${summary.counterpartyName}.',
                                        );
                                      } else {
                                        _showMessage('Could not send request right now.');
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(0xFF1A4A8F),
                              ),
                              child: Text(
                                isRequestPending ? 'Requested' : 'Request',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ] else if (owesMe && isPendingApproval) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: null,
                              child: const Text('Awaiting your action'),
                            ),
                          ),
                        ] else if (owesMe && isPaymentDone) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: null,
                              child: const Text('Payment done'),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: null,
                              child: const Text('Settled'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<_SettleUpSummary> _buildSettleUpSummaries({
    required List<_GroupTransaction> transactions,
    required String currentUserId,
  }) {
    final settlementTransactions = transactions
        .where((tx) => tx.settlementDetails != null)
        .toList();
    final details = settlementTransactions
        .map((tx) => tx.settlementDetails)
        .whereType<_SettlementTransactionDetails>()
        .toList();

    final nameByUserId = <String, String>{};
    for (final detail in details) {
      if (detail.debtorUserId.isNotEmpty) {
        nameByUserId[detail.debtorUserId] = detail.debtorName;
      }
      if (detail.creditorUserId.isNotEmpty) {
        nameByUserId[detail.creditorUserId] = detail.creditorName;
      }
    }

    final latestActivityByUserId = <String, DateTime>{};
    for (final tx in settlementTransactions) {
      final detail = tx.settlementDetails;
      if (detail == null) {
        continue;
      }

      final debtorLatest = latestActivityByUserId[detail.debtorUserId];
      if (debtorLatest == null || tx.sortKey.isAfter(debtorLatest)) {
        latestActivityByUserId[detail.debtorUserId] = tx.sortKey;
      }

      final creditorLatest = latestActivityByUserId[detail.creditorUserId];
      if (creditorLatest == null || tx.sortKey.isAfter(creditorLatest)) {
        latestActivityByUserId[detail.creditorUserId] = tx.sortKey;
      }
    }

    final minimizedTransfers = computeMinimumSettlements(
      obligations: details
          .map(
            (detail) => SettlementTransfer(
              payerUserId: detail.debtorUserId,
              payeeUserId: detail.creditorUserId,
              amountCents: detail.amountCents,
            ),
          )
          .toList(),
    );

    final map = <String, _SettleUpSummary>{};

    for (final transfer in minimizedTransfers) {
      final isCurrentDebtor = transfer.payerUserId == currentUserId;
      final isCurrentCreditor = transfer.payeeUserId == currentUserId;
      if (!isCurrentDebtor && !isCurrentCreditor) {
        continue;
      }

      final counterpartyUserId =
          isCurrentDebtor ? transfer.payeeUserId : transfer.payerUserId;
      final counterpartyName = nameByUserId[counterpartyUserId] ?? 'Member';

      final fromName = nameByUserId[transfer.payerUserId] ?? 'Member';
      final toName = nameByUserId[transfer.payeeUserId] ?? 'Member';
      final activityAt =
          latestActivityByUserId[counterpartyUserId] ?? DateTime.fromMillisecondsSinceEpoch(0);

      final summary = map.putIfAbsent(
        counterpartyUserId,
        () => _SettleUpSummary(
          counterpartyUserId: counterpartyUserId,
          counterpartyName: counterpartyName,
          netCents: 0,
          ledgerLines: <_CounterpartyLedgerLine>[],
          latestActivityAt: activityAt,
        ),
      );

      if (activityAt.isAfter(summary.latestActivityAt)) {
        summary.latestActivityAt = activityAt;
      }

      summary.ledgerLines.add(
        _CounterpartyLedgerLine(
          fromName: fromName,
          toName: toName,
          amountCents: transfer.amountCents,
          occurredAt: activityAt,
        ),
      );

      if (isCurrentDebtor) {
        summary.netCents += transfer.amountCents;
      } else {
        summary.netCents -= transfer.amountCents;
      }
    }

    final summaries = map.values.where((item) => item.netCents != 0).toList();
    summaries.sort((a, b) {
      final byLatest = b.latestActivityAt.compareTo(a.latestActivityAt);
      if (byLatest != 0) {
        return byLatest;
      }
      return b.netCents.abs().compareTo(a.netCents.abs());
    });
    return summaries;
  }

  Future<void> _openCounterpartyLedgerDialog(_SettleUpSummary summary) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final sortedLedgerLines = List<_CounterpartyLedgerLine>.from(summary.ledgerLines)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

        return AlertDialog(
          title: Text('Transactions with ${summary.counterpartyName}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...sortedLedgerLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${line.fromName} needs to pay ${_money(line.amountCents / 100)} to ${line.toName}',
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  Text(
                    summary.netCents > 0
                        ? 'Net: You need to pay ${_money(summary.netCents / 100)} to ${summary.counterpartyName}'
                        : 'Net: ${summary.counterpartyName} needs to pay you ${_money(summary.netCents.abs() / 100)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
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

  List<_GroupTransaction> _buildSettlementPreviewTransactions({
    required String expenseName,
    required List<_MemberOption> members,
    required Map<String, double> paidByUserId,
    required Map<String, bool> includeMap,
    required String? currentUserId,
  }) {
    int toCents(double value) => (value * 100).round();
    final now = DateTime.now();
    final selected = members.where((m) => includeMap[m.userId] ?? false).toList();
    if (selected.isEmpty) {
      return <_GroupTransaction>[];
    }

    final totalCents = paidByUserId.values.fold<int>(0, (sum, amount) => sum + toCents(amount));
    if (totalCents <= 0) {
      return <_GroupTransaction>[];
    }

    final shareBase = totalCents ~/ selected.length;
    final remainder = totalCents % selected.length;
    final extraByUserId = <String, int>{};
    for (var i = 0; i < selected.length; i++) {
      extraByUserId[selected[i].userId] = i < remainder ? 1 : 0;
    }

    final nameByUserId = <String, String>{for (final m in members) m.userId: m.displayName};
    final paidLines = members
        .map(
          (member) => _PaidByLine(
            memberName: member.displayName,
            amount: (paidByUserId[member.userId] ?? 0),
          ),
        )
        .toList();
    final participantNames = selected.map((member) => member.displayName).toList();
    final expenseDetails = _ExpenseTransactionDetails(
      expenseName: expenseName,
      totalAmount: totalCents / 100,
      paidBy: paidLines,
      participants: participantNames,
    );

    final creditors = <_SplitNode>[];
    final debtors = <_SplitNode>[];

    for (final member in members) {
      final paid = toCents(paidByUserId[member.userId] ?? 0);
      final selectedShare = includeMap[member.userId] == true
          ? (shareBase + (extraByUserId[member.userId] ?? 0))
          : 0;
      final balance = paid - selectedShare;

      if (balance > 0) {
        creditors.add(_SplitNode(userId: member.userId, amountCents: balance));
      } else if (balance < 0) {
        debtors.add(_SplitNode(userId: member.userId, amountCents: -balance));
      }
    }

    creditors.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    debtors.sort((a, b) => b.amountCents.compareTo(a.amountCents));

    final results = <_GroupTransaction>[];
    var ci = 0;
    var di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final creditor = creditors[ci];
      final debtor = debtors[di];
      final transfer = creditor.amountCents < debtor.amountCents
          ? creditor.amountCents
          : debtor.amountCents;

      final debtorName = nameByUserId[debtor.userId] ?? 'Member';
      final creditorName = nameByUserId[creditor.userId] ?? 'Member';
      final isCreditForCurrentUser = creditor.userId == currentUserId;

      results.add(
        _GroupTransaction(
          sortKey: now,
          date: _formatDate(now).split(',').first,
          title: '$debtorName pays $creditorName',
          subtitle: expenseName,
          amount: transfer / 100,
          isCredit: isCreditForCurrentUser,
          icon: Icons.swap_horiz,
          settlementDetails: _SettlementTransactionDetails(
            debtorUserId: debtor.userId,
            debtorName: debtorName,
            creditorUserId: creditor.userId,
            creditorName: creditorName,
            amountCents: transfer,
          ),
        ),
      );

      creditor.amountCents -= transfer;
      debtor.amountCents -= transfer;

      if (creditor.amountCents <= 0) {
        ci++;
      }
      if (debtor.amountCents <= 0) {
        di++;
      }
    }

    final expenseRow = _GroupTransaction(
      sortKey: now,
      date: _formatDate(now).split(',').first,
      title: expenseName,
      subtitle: 'Expense added',
      amount: totalCents / 100,
      isCredit: false,
      icon: Icons.receipt_long,
      expenseDetails: expenseDetails,
    );

    if (results.isEmpty) {
      return <_GroupTransaction>[expenseRow];
    }

    return <_GroupTransaction>[expenseRow, ...results];
  }

  Future<void> _openAddMemberDialog(GroupSummary group) async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final upiController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Members - ${group.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Member email',
                    hintText: 'friend@email.com',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: upiController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID (optional)',
                    hintText: 'name@bank',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = emailController.text.trim().toLowerCase();
                if (!email.contains('@')) {
                  _showMessage('Enter a valid email address.');
                  return;
                }

                Navigator.of(context).pop();
                await _sendInvite(
                  group,
                  inviteeEmail: email,
                  inviteeName:
                      nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                  inviteeUpi:
                      upiController.text.trim().isEmpty ? null : upiController.text.trim(),
                );
              },
              child: const Text('Send Invite'),
            ),
          ],
        );
      },
    );
  }

  Future<List<_GroupMemberDirectoryItem>> _fetchGroupMembersDirectory(String groupId) async {
    final rows = await _client.rpc('get_group_members_with_email', params: {
      '_group_id': groupId,
    }) as List<dynamic>;

    return rows
        .map(
          (row) => _GroupMemberDirectoryItem(
            userId: row['user_id']?.toString() ?? '',
            name: row['display_name']?.toString() ?? 'Member',
            email: row['email']?.toString() ?? '',
            role: row['role']?.toString() ?? 'member',
          ),
        )
        .where((member) => member.userId.isNotEmpty)
        .toList();
  }

  Future<String?> _askMemberEmail() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add member'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'User email',
              hintText: 'friend@email.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final email = controller.text.trim().toLowerCase();
                if (!email.contains('@')) {
                  _showMessage('Enter a valid email address.');
                  return;
                }
                Navigator.of(context).pop(email);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _addMemberByEmail(GroupSummary group, String email) async {
    try {
      await _client.rpc('add_group_member_by_email', params: {
        '_group_id': group.id,
        '_invitee_email': email,
      });
      _showMessage('Member added: $email');
      return true;
    } on PostgrestException catch (error) {
      _showMessage('Could not add member (${error.message}).');
      return false;
    } catch (_) {
      _showMessage('Unable to add member right now.');
      return false;
    }
  }

  Future<bool> _removeMemberByUserId(
    GroupSummary group,
    _GroupMemberDirectoryItem member,
  ) async {
    final user = _currentUser;
    if (user == null) {
      return false;
    }

    if (group.createdByUserId != user.id) {
      _showMessage('Only the group creator can remove members.');
      return false;
    }

    if (member.userId == group.createdByUserId || member.role == 'owner') {
      _showMessage('Group creator cannot be removed.');
      return false;
    }

    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', group.id)
          .eq('user_id', member.userId);

      _showMessage('${member.name} removed from group.');
      return true;
    } on PostgrestException catch (error) {
      _showMessage('Could not remove member (${error.message}).');
      return false;
    } catch (_) {
      _showMessage('Unable to remove member right now.');
      return false;
    }
  }

  Future<void> _exitGroup(GroupSummary group) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    if (group.createdByUserId == user.id) {
      _showMessage('Group creator cannot exit. Delete the group instead.');
      return;
    }

    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Exit group?'),
              content: Text('You will leave "${group.name}".'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldExit) {
      return;
    }

    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', group.id)
          .eq('user_id', user.id);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      _showMessage('You exited ${group.name}.');
      await _loadData();
    } on PostgrestException catch (error) {
      _showMessage('Could not exit group (${error.message}).');
    } catch (_) {
      _showMessage('Unable to exit group right now.');
    }
  }

  Future<void> _openMembersDirectoryPopup(GroupSummary group) async {
    final isCreator = group.createdByUserId == _currentUser?.id;
    Future<List<_GroupMemberDirectoryItem>> membersFuture =
        _fetchGroupMembersDirectory(group.id);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: SizedBox(
                width: 560,
                height: 560,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${group.name} members',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Creator: ${group.createdByName}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFF5A6E82),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            FutureBuilder<List<_GroupMemberDirectoryItem>>(
                              future: membersFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Could not load members.',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  );
                                }

                                final members = snapshot.data ?? <_GroupMemberDirectoryItem>[];
                                if (members.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No members found for this group.',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  itemCount: members.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final member = members[index];
                                    final canRemove = isCreator &&
                                        member.userId != group.createdByUserId &&
                                        member.role != 'owner';
                                    final isGroupCreator = member.userId == group.createdByUserId;
                                    return ListTile(
                                      tileColor: const Color(0xFFF3F8FD),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFD8ECFA),
                                        child: Text(
                                          member.name.isNotEmpty
                                              ? member.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(color: Color(0xFF1D6CAB)),
                                        ),
                                      ),
                                      title: Text(member.name),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(member.email.isEmpty ? 'No email available' : member.email),
                                          if (isGroupCreator)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD8ECFA),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Creator',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1D6CAB),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: canRemove
                                          ? IconButton(
                                              tooltip: 'Remove member',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Color(0xFFB33A2E),
                                              ),
                                              onPressed: () async {
                                                final remove = await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) {
                                                        return AlertDialog(
                                                          title: const Text('Remove member?'),
                                                          content: Text(
                                                            'Remove ${member.name} from ${group.name}?',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.of(context).pop(false),
                                                              child: const Text('Cancel'),
                                                            ),
                                                            FilledButton(
                                                              style: FilledButton.styleFrom(
                                                                backgroundColor: const Color(0xFFB33A2E),
                                                              ),
                                                              onPressed: () => Navigator.of(context).pop(true),
                                                              child: const Text('Remove'),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ) ??
                                                    false;

                                                if (!remove) {
                                                  return;
                                                }

                                                final removed = await _removeMemberByUserId(group, member);
                                                if (!removed) {
                                                  return;
                                                }

                                                if (!mounted) {
                                                  return;
                                                }

                                                setModalState(() {
                                                  membersFuture = _fetchGroupMembersDirectory(group.id);
                                                });
                                                await _loadData();
                                              },
                                            )
                                          : null,
                                    );
                                  },
                                );
                              },
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: FloatingActionButton.extended(
                                onPressed: isCreator
                                    ? () async {
                                        final email = await _askMemberEmail();
                                        if (email == null || email.isEmpty) {
                                          return;
                                        }

                                        final added = await _addMemberByEmail(group, email);
                                        if (!added) {
                                          return;
                                        }

                                        if (!mounted) {
                                          return;
                                        }

                                        setModalState(() {
                                          membersFuture = _fetchGroupMembersDirectory(group.id);
                                        });
                                        await _loadData();
                                      }
                                    : () => _exitGroup(group),
                                backgroundColor:
                                    isCreator ? const Color(0xFF1A4A8F) : const Color(0xFFB33A2E),
                                icon: Icon(
                                  isCreator ? Icons.person_add_alt_1 : Icons.logout_rounded,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  isCreator ? 'Add member' : 'Exit Group',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInviteDialog(GroupSummary group) async {
    _inviteEmailController.clear();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invite to ${group.name}'),
          content: TextField(
            controller: _inviteEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'friend@email.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = _inviteEmailController.text.trim().toLowerCase();
                if (!email.contains('@')) {
                  _showMessage('Enter a valid email address.');
                  return;
                }
                Navigator.of(context).pop();
                await _sendInvite(group, inviteeEmail: email);
              },
              child: const Text('Send Invite'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendInvite(
    GroupSummary group, {
    required String inviteeEmail,
    String? inviteeName,
    String? inviteeUpi,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    try {
      await _client.from('group_invitations').insert({
        'group_id': group.id,
        'inviter_user_id': user.id,
        'inviter_name': user.email ?? 'Group member',
        'invitee_email': inviteeEmail,
        'invitee_name': inviteeName,
        'invitee_upi': inviteeUpi,
        'status': 'pending',
      });

      if (!mounted) {
        return;
      }

      _showMessage('Invite sent to $inviteeEmail.');
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not send invite (${error.message}).');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Unable to send invite right now.');
    }
  }

  Future<void> _respondToInvite(GroupInvitation invite, String nextStatus) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    try {
      if (nextStatus == 'accepted') {
        await _client.rpc('accept_group_invitation', params: {
          '_invite_id': invite.id,
        });
      } else {
        await _client.from('group_invitations').update({
          'status': nextStatus,
          'responded_at': DateTime.now().toIso8601String(),
        }).eq('id', invite.id);
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        nextStatus == 'accepted'
            ? 'You joined ${invite.groupName}.'
            : 'Invitation declined.',
      );
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not update invite (${error.message}).');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Unable to process invitation right now.');
    }
  }

  Future<void> _removeMemberFromGroup(
    GroupSummary group,
    GroupMemberBalance member,
  ) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    if (member.balance.abs() > 0.009) {
      _showMessage('Settle member balance before removing from group.');
      return;
    }

    final isSelf = member.userId == user.id;
    final canRemove = group.createdByUserId == user.id || isSelf;
    if (!canRemove) {
      _showMessage('Only group creator can remove members.');
      return;
    }

    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', group.id)
          .eq('user_id', member.userId);

      if (!mounted) {
        return;
      }

      _showMessage(isSelf ? 'You left the group.' : '${member.memberName} removed.');
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not remove member (${error.message}).');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Unable to remove member right now.');
    }
  }

  Future<void> _onGroupLongPress(GroupSummary group) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    if (group.createdByUserId != user.id) {
      _showMessage('Only the group creator can delete this group.');
      return;
    }

    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete group?'),
              content: Text(
                'Delete "${group.name}" for all members? This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB33A2E),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    try {
      await _client.from('groups').delete().eq('id', group.id);

      if (!mounted) {
        return;
      }

      _showMessage('Group deleted.');
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not delete group (${error.message}).');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Unable to delete group right now.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyLoadError(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    if (code == '42P01' ||
        code == 'PGRST205' ||
        message.contains('could not find the table') ||
        (message.contains('relation') && message.contains('does not exist'))) {
      return 'Could not load groups data. Missing table(s): groups, group_members, group_invitations, group_expenses, or group_settlements. Run the migration in supabase/migrations/20260313_groups_schema.sql.';
    }

    if (code == '42501' || message.contains('permission denied')) {
      return 'Could not load groups data due to permissions. Check Supabase RLS policies and table grants for authenticated users.';
    }

    return 'Could not load groups data. ${error.message}';
  }

  static String _memberSuffix(String? id) {
    if (id == null || id.length < 6) {
      return 'User';
    }
    return id.substring(0, 6);
  }

  static String _memberStatus(double balance) {
    if (balance > 0) {
      return 'Gets back';
    }
    if (balance < 0) {
      return 'Owes';
    }
    return 'Settled';
  }

  static double _sumSince(List<GroupExpense> expenses, DateTime from) {
    var total = 0.0;
    for (final expense in expenses) {
      if (expense.date.isAfter(from)) {
        total += expense.amount;
      }
    }
    return total;
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

  static String _money(double value) {
    final sign = value < 0 ? '-' : '';
    return '$sign₹${value.abs().toStringAsFixed(2)}';
  }
  static String _formatDate(DateTime date) {
    const monthNames = [
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

    final month = monthNames[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    return '$month $day, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _ensureFabController();
    final topInset = MediaQuery.of(context).padding.top;

    if (_loadError != null) {
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

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
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 104),
              children: [
                Text(
                  'Groups',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (_groups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _isLoading
                          ? 'Loading groups...'
                          : 'No groups yet. Create one and invite members by email.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ..._groups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GroupBar(
                        group: group,
                        onTap: () => _openGroupDetailPopup(group),
                        onLongPress: () => _onGroupLongPress(group),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Positioned(
            right: 16,
            bottom: 18,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _fabEntranceController!,
                curve: Curves.easeOut,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(
                  CurvedAnimation(
                    parent: _fabEntranceController!,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: FloatingActionButton.extended(
                  onPressed: _openCreateGroupDialog,
                  backgroundColor: Colors.black,
                  tooltip: 'New Group',
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'New Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBar extends StatelessWidget {
  const _GroupBar({
    required this.group,
    required this.onTap,
    this.onLongPress,
  });

  final GroupSummary group;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final totalExpenses = _safeDouble(() => group.totalExpenses);

    final toPay = _safeDouble(() => group.toPayAmount);
    final toReceive = _safeDouble(() => group.toReceiveAmount);
    final bool isOwe = toPay > 0;
    final bool isOwed = toReceive > 0;
    final money = isOwe
      ? _GroupsScreenState._money(-toPay)
      : isOwed
        ? _GroupsScreenState._money(toReceive)
        : _GroupsScreenState._money(0);
    final Color amountColor = isOwe
        ? const Color(0xFFB33A2E)
        : isOwed
            ? const Color(0xFF1B7D3A)
            : const Color(0xFF5C6470);
    final String caption = isOwe
      ? 'To Pay'
      : isOwed
        ? 'To Receive'
        : 'Settled up';

    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(36),
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFD8ECFA),
                foregroundColor: const Color(0xFF1D6CAB),
                child: Icon(_iconFor(group.icon), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created by ${group.createdByName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5A6E82),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${group.memberCount} members',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF3A4450),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Total spending: ${_GroupsScreenState._money(totalExpenses)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF3A4450),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _safeDouble(double Function() reader) {
    try {
      return reader();
    } catch (_) {
      return 0;
    }
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
}

void _showEmptyDialog(BuildContext context, String title) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: const Text('This will be implemented in a later iteration.'),
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.amountColor,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A4A8F).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A4450),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            amount == 0 ? '₹0.00' : '₹${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: amountColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    this.onTap,
    this.compactVisual = false,
  });

  final _GroupTransaction transaction;
  final VoidCallback? onTap;
  final bool compactVisual;

  @override
  Widget build(BuildContext context) {
    final dateParts = transaction.date.trim().split(RegExp(r'\s+'));
    final topDate = dateParts.isEmpty ? transaction.date : dateParts.first;
    final bottomDate = dateParts.length > 1 ? dateParts.sublist(1).join(' ') : '';
    final dateWidth = compactVisual ? 56.0 : 60.0;
    final iconSquare = compactVisual ? 40.0 : 44.0;
    final iconSize = compactVisual ? 20.0 : 21.0;
    final sideGap = compactVisual ? 8.0 : 9.0;
    final titleSize = compactVisual ? 14.5 : 16.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A4A8F).withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: dateWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F4FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          topDate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF3A4450),
                                fontWeight: FontWeight.w800,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (bottomDate.isNotEmpty)
                          Text(
                            bottomDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF3A4450),
                                  fontWeight: FontWeight.w800,
                                ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: sideGap),
                SizedBox(
                  width: iconSquare,
                  height: iconSquare,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      transaction.icon,
                      color: const Color(0xFF1D6CAB),
                      size: iconSize,
                    ),
                  ),
                ),
                SizedBox(width: sideGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        transaction.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5A6E82),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 102,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${transaction.isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: transaction.isCredit
                                  ? const Color(0xFF1B7D3A)
                                  : const Color(0xFFB33A2E),
                            ),
                      ),
                    ),
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

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: value == null
          ? Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
            )
          : RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
    );
  }
}

class _InvitationSection extends StatelessWidget {
  const _InvitationSection({
    required this.invitations,
    required this.onAccept,
    required this.onDecline,
  });

  final List<GroupInvitation> invitations;
  final ValueChanged<GroupInvitation> onAccept;
  final ValueChanged<GroupInvitation> onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invitation Requests',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (invitations.isEmpty)
            Text(
              'No pending requests right now.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...invitations.map(
              (invite) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invite.groupName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Invited by ${invite.inviterName}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => onDecline(invite),
                      child: const Text('Decline'),
                    ),
                    FilledButton(
                      onPressed: () => onAccept(invite),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupDetailsView extends StatelessWidget {
  const _GroupDetailsView({
    required this.group,
    required this.details,
    required this.currentUserId,
    required this.onPay,
    required this.onRemoveMember,
    required this.onAddExpense,
    required this.onAddMembers,
  });

  final GroupSummary group;
  final GroupDetailsData details;
  final String? currentUserId;
  final ValueChanged<GroupMemberBalance> onPay;
  final ValueChanged<GroupMemberBalance> onRemoveMember;
  final VoidCallback onAddExpense;
  final VoidCallback onAddMembers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 640,
      height: 620,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFD8ECFA),
                child: Icon(_GroupBar._iconFor(group.icon), color: const Color(0xFF1D6CAB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                _OverviewCard(group: group, details: details),
                const SizedBox(height: 12),
                _MemberBalanceCard(
                  members: details.members,
                  currentUserId: currentUserId,
                  isOwner: group.createdByUserId == currentUserId,
                  onPay: onPay,
                  onRemoveMember: onRemoveMember,
                ),
                const SizedBox(height: 12),
                _ExpenseListCard(expenses: details.expenses),
                const SizedBox(height: 12),
                _ActionCard(
                  onAddExpense: onAddExpense,
                  onAddMembers: onAddMembers,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.group, required this.details});

  final GroupSummary group;
  final GroupDetailsData details;

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Group Overview',
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: [
          _Metric(label: 'Members', value: '${group.memberCount}'),
          _Metric(label: 'Total Expenses', value: _GroupsScreenState._money(group.totalExpenses)),
          _Metric(label: 'Total Owed', value: _GroupsScreenState._money(group.totalOwed)),
          _Metric(label: 'Balance', value: _GroupsScreenState._money(group.balance)),
          _Metric(
            label: 'Weekly Spending',
            value: _GroupsScreenState._money(details.weeklySpending),
          ),
          _Metric(
            label: 'Monthly Spending',
            value: _GroupsScreenState._money(details.monthlySpending),
          ),
          _Metric(label: 'Transactions', value: '${details.totalTransactions}'),
        ],
      ),
    );
  }
}

class _MemberBalanceCard extends StatelessWidget {
  const _MemberBalanceCard({
    required this.members,
    required this.currentUserId,
    required this.isOwner,
    required this.onPay,
    required this.onRemoveMember,
  });

  final List<GroupMemberBalance> members;
  final String? currentUserId;
  final bool isOwner;
  final ValueChanged<GroupMemberBalance> onPay;
  final ValueChanged<GroupMemberBalance> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Member Balance List',
      child: members.isEmpty
          ? const Text('No members found.')
          : Column(
              children: members
                  .map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.memberName),
                                Text(
                                  '${member.status} • ${_GroupsScreenState._money(member.balance)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: member.balance == 0 ? null : () => onPay(member),
                            child: const Text('Pay'),
                          ),
                          const SizedBox(width: 8),
                          if (isOwner || member.userId == currentUserId)
                            OutlinedButton(
                              onPressed: () => onRemoveMember(member),
                              child: Text(
                                member.userId == currentUserId ? 'Leave' : 'Remove',
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ExpenseListCard extends StatelessWidget {
  const _ExpenseListCard({required this.expenses});

  final List<GroupExpense> expenses;

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Expense List',
      child: expenses.isEmpty
          ? const Text('No expenses yet.')
          : Column(
              children: expenses
                  .map(
                    (expense) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F9FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.description,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Amount: ${expense.amount < 0 ? '-' : ''}₹${expense.amount.abs().toStringAsFixed(2)}',
                          ),
                          Text('Paid by: ${expense.paidBy}'),
                          Text(
                            'Date: ${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}',
                          ),
                          Text('Split: ${expense.owesWhom}'),
                          if ((expense.billImageUrl ?? '').isNotEmpty)
                            Text(
                              'Bill image attached',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.onAddExpense,
    required this.onAddMembers,
  });

  final VoidCallback onAddExpense;
  final VoidCallback onAddMembers;

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Group Actions',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(label: const Text('Add Expense'), onPressed: onAddExpense),
          ActionChip(label: const Text('Add Members'), onPressed: onAddMembers),
          const _InfoChip(label: 'Split Expenses'),
          const _InfoChip(label: 'Settle Balances'),
          const _InfoChip(label: 'View Analytics'),
          const _InfoChip(label: 'Transaction History'),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('$label is available in this popup context.')),
          );
      },
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MemberOption {
  const _MemberOption({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

class _GroupMemberDirectoryItem {
  const _GroupMemberDirectoryItem({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  final String userId;
  final String name;
  final String email;
  final String role;
}

class _SplitNode {
  _SplitNode({required this.userId, required this.amountCents});

  final String userId;
  int amountCents;
}

class GroupSummary {
  GroupSummary({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
    required this.totalExpenses,
    required this.totalOwed,
    required this.balance,
    required this.memberCount,
    this.settlementStatus,
    this.toPayAmount = 0,
    this.toReceiveAmount = 0,
  });

  final String id;
  final String name;
  final String icon;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;
  final double totalExpenses;
  final double totalOwed;
  final double balance;
  final double toPayAmount;
  final double toReceiveAmount;
  final int memberCount;
  final String? settlementStatus;
}

class GroupInvitation {
  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviterName,
    required this.inviteeEmail,
    required this.status,
    this.inviteeName,
    this.inviteeUpi,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String inviterName;
  final String inviteeEmail;
  final String status;
  final String? inviteeName;
  final String? inviteeUpi;
}

class GroupMemberBalance {
  GroupMemberBalance({
    required this.userId,
    required this.memberName,
    required this.balance,
    required this.status,
    this.upiId,
  });

  final String userId;
  final String memberName;
  final double balance;
  final String status;
  final String? upiId;
}

class GroupExpense {
  GroupExpense({
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.date,
    required this.createdAt,
    required this.owesWhom,
    this.billImageUrl,
  });

  final String description;
  final double amount;
  final String paidBy;
  final DateTime date;
  final DateTime createdAt;
  final String owesWhom;
  final String? billImageUrl;
}

class GroupDetailsData {
  GroupDetailsData({
    required this.members,
    required this.expenses,
    required this.splitSettlementTransactions,
    required this.weeklySpending,
    required this.monthlySpending,
    required this.totalTransactions,
  });

  final List<GroupMemberBalance> members;
  final List<GroupExpense> expenses;
  final List<_GroupTransaction> splitSettlementTransactions;
  final double weeklySpending;
  final double monthlySpending;
  final int totalTransactions;
}
