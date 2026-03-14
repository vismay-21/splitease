import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final _fakeGroups = [
  GroupSummary(
    id: 'grp1',
    name: 'Trip to Goa',
    icon: 'airplanemode_active',
    createdByUserId: 'Ayaan K.',
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
    totalExpenses: 3450.00,
    totalOwed: 1000.00,
    balance: 280.75,
    memberCount: 3,
    settlementStatus: 'Active',
  ),
];

class _GroupTransaction {
  const _GroupTransaction({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.icon,
  });

  final String date;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final IconData icon;
}

class _SettleMember {
  _SettleMember({
    required this.name,
    required this.balance,
  });

  final String name;
  double balance;
}

const _fakeTransactions = [
  _GroupTransaction(
    date: 'Apr 04',
    title: 'Grocery',
    subtitle: 'You paid',
    amount: 20.50,
    isCredit: false,
    icon: Icons.shopping_bag_outlined,
  ),
  _GroupTransaction(
    date: 'May 02',
    title: 'Train refund price',
    subtitle: 'You lent',
    amount: 1600.00,
    isCredit: true,
    icon: Icons.train,
  ),
  _GroupTransaction(
    date: 'May 11',
    title: 'Dinner',
    subtitle: 'You paid',
    amount: 430.00,
    isCredit: false,
    icon: Icons.restaurant_outlined,
  ),
  _GroupTransaction(
    date: 'May 23',
    title: 'Taxi share',
    subtitle: 'You paid',
    amount: 35.20,
    isCredit: false,
    icon: Icons.directions_car_outlined,
  ),
  _GroupTransaction(
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

    // Simulate a short loading delay.
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    setState(() {
      _groups = List<GroupSummary>.from(_fakeGroups);
      _pendingInvitations = [];
      _isLoading = false;
      _hasLoadedOnce = true;
      _cachedGroups = List<GroupSummary>.from(_groups);
      _cachedInvitations = List<GroupInvitation>.from(_pendingInvitations);
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

    final groupRows = await _client
        .from('groups')
      .select('id,name,icon,created_by,total_expenses,total_owed,balance,settlement_status')
        .inFilter('id', groupIds) as List<dynamic>;

    final memberCounts = await _fetchMemberCounts(groupIds);

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
          totalExpenses: _asDouble(row['total_expenses']),
          totalOwed: _asDouble(row['total_owed']),
          balance: _asDouble(row['balance']),
          settlementStatus: row['settlement_status']?.toString(),
          memberCount: memberCounts[groupId] ?? 0,
        ),
      );
    }

    summaries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return summaries;
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
        .select('description,amount,paid_by_name,expense_date,owes_summary,bill_image_url')
        .eq('group_id', group.id)
        .order('expense_date', ascending: false) as List<dynamic>;

    final expenses = expenseRows
        .map(
          (row) => GroupExpense(
            description: row['description']?.toString() ?? 'Expense',
            amount: _asDouble(row['amount']),
            paidBy: row['paid_by_name']?.toString() ?? 'Unknown',
            date: DateTime.tryParse(row['expense_date']?.toString() ?? '') ?? DateTime.now(),
            owesWhom: row['owes_summary']?.toString() ?? 'Split equally',
            billImageUrl: row['bill_image_url']?.toString(),
          ),
        )
        .toList();

    final weekly = _sumSince(expenses, DateTime.now().subtract(const Duration(days: 7)));
    final monthly = _sumSince(expenses, DateTime.now().subtract(const Duration(days: 30)));

    return GroupDetailsData(
      members: memberBalances,
      expenses: expenses,
      weeklySpending: weekly,
      monthlySpending: monthly,
      totalTransactions: expenses.length,
    );
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

  Future<void> _openGroupDetailPopup(GroupSummary group) async {
    final youOwe = group.balance < 0 ? -group.balance : 0.0;
    final youAreOwed = group.balance > 0 ? group.balance : 0.0;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.82;
        final maxWidth = MediaQuery.of(context).size.width * 0.92;
        final createdDate = 'Apr 04, 2024';

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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: const Color(0xFFD8ECFA),
                                      foregroundColor: const Color(0xFF1D6CAB),
                                      child: Icon(
                                        _GroupBar._iconFor(group.icon),
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 18, color: Color(0xFF5A6E82)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Created by ${group.createdByUserId}',
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
                          ],
                        ),
                      ),
                      const Divider(height: 1),

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
                      const Divider(height: 1),

                      // Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _openSettleUpPopup(group),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A4A8F),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Settle up',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _showEmptyDialog(context, 'Balances'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A4A8F),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Balances',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Transactions list section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _fakeTransactions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final transaction = _fakeTransactions[index];
                            return _TransactionRow(
                              transaction: transaction,
                            );
                          },
                        ),
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
                        const Divider(height: 1),
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
                                    ? 'Owes you'
                                    : iOwe
                                        ? 'You owe'
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
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _showMessage('Open UPI payment flow (stub).');
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
    if ((receiver.upiId ?? '').isEmpty) {
      _showMessage('This member has no UPI ID yet. Ask them to update it.');
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

    final upiUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: <String, String>{
        'pa': receiver.upiId!,
        'pn': receiver.memberName,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'SpliTease ${group.name}',
        'tr': settlementId,
        'url': callbackUri,
      },
    );

    final launched = await launchUrl(upiUri, mode: LaunchMode.externalApplication);
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
              title: const Text('Create Group'),
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
                    items: const [
                      DropdownMenuItem(value: 'group', child: Text('Group')),
                      DropdownMenuItem(value: 'food', child: Text('Food')),
                      DropdownMenuItem(value: 'flight', child: Text('Trip')),
                      DropdownMenuItem(value: 'home', child: Text('Home')),
                      DropdownMenuItem(value: 'sports', child: Text('Sports')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedIcon = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Icon'),
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

  Future<void> _openAddExpenseDialog(GroupSummary group) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final summaryController = TextEditingController();

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

      if (!mounted) {
        return;
      }

      String selectedPayer = _currentUser?.id ?? members.first.userId;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                title: Text('Add Expense - ${group.name}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPayer,
                        items: members
                            .map(
                              (member) => DropdownMenuItem(
                                value: member.userId,
                                child: Text(member.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedPayer = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Paid by'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: summaryController,
                        decoration: const InputDecoration(
                          labelText: 'Who owes whom (optional)',
                          hintText: 'A owes B 200, C owes B 200',
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
                      final description = descriptionController.text.trim();
                      final amount = double.tryParse(amountController.text.trim());
                      if (description.isEmpty || amount == null || amount <= 0) {
                        _showMessage('Enter valid description and amount.');
                        return;
                      }

                      final payer = members.firstWhere(
                        (member) => member.userId == selectedPayer,
                        orElse: () => members.first,
                      );

                      await _client.rpc('add_group_expense_equal_split', params: {
                        '_group_id': group.id,
                        '_description': description,
                        '_amount': amount,
                        '_paid_by_user_id': payer.userId,
                        '_owes_summary': summaryController.text.trim().isEmpty
                            ? null
                            : summaryController.text.trim(),
                        '_bill_image_url': null,
                      });

                      if (!mounted) {
                        return;
                      }
                      Navigator.of(this.context).pop();
                      _showMessage('Expense added successfully.');
                      await _loadData();
                    },
                    child: const Text('Add Expense'),
                  ),
                ],
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
              Color(0xFFE9F4FF),
              Color(0xFFF1F8FF),
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
            Color(0xFFE9F4FF),
            Color(0xFFF1F8FF),
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
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
  });

  final GroupSummary group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalExpenses = _safeDouble(() => group.totalExpenses);

    final money = _GroupsScreenState._money(group.balance);
    final bool isOwed = group.balance > 0;
    final bool isOwe = group.balance < 0;
    final Color amountColor = isOwe
        ? const Color(0xFFB33A2E)
        : isOwed
            ? const Color(0xFF1B7D3A)
            : const Color(0xFF5C6470);
    final String caption = isOwe
        ? 'You owe'
        : isOwed
            ? 'You are owed'
            : 'Settled up';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                      'Created by ${group.createdByUserId}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5A6E82),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${group.memberCount} members  •  Total spending: ${_GroupsScreenState._money(totalExpenses)}',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 7),
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
  const _TransactionRow({required this.transaction});

  final _GroupTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    transaction.date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF3A4450),
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  transaction.icon,
                  color: const Color(0xFF1D6CAB),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    transaction.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5A6E82),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                '${transaction.isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: transaction.isCredit ? const Color(0xFF1B7D3A) : const Color(0xFFB33A2E),
                    ),
              ),
            ),
          ],
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
                          Text('Amount: ${_GroupsScreenState._money(expense.amount)}'),
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

class GroupSummary {
  GroupSummary({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdByUserId,
    required this.totalExpenses,
    required this.totalOwed,
    required this.balance,
    required this.memberCount,
    this.settlementStatus,
  });

  final String id;
  final String name;
  final String icon;
  final String createdByUserId;
  final double totalExpenses;
  final double totalOwed;
  final double balance;
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
    required this.owesWhom,
    this.billImageUrl,
  });

  final String description;
  final double amount;
  final String paidBy;
  final DateTime date;
  final String owesWhom;
  final String? billImageUrl;
}

class GroupDetailsData {
  GroupDetailsData({
    required this.members,
    required this.expenses,
    required this.weeklySpending,
    required this.monthlySpending,
    required this.totalTransactions,
  });

  final List<GroupMemberBalance> members;
  final List<GroupExpense> expenses;
  final double weeklySpending;
  final double monthlySpending;
  final int totalTransactions;
}
