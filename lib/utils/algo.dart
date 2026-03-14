class SettlementTransfer {
  const SettlementTransfer({
    required this.payerUserId,
    required this.payeeUserId,
    required this.amountCents,
  });

  final String payerUserId;
  final String payeeUserId;
  final int amountCents;
}

class _BalanceNode {
  _BalanceNode({required this.userId, required this.amountCents});

  final String userId;
  int amountCents;
}

List<SettlementTransfer> computeMinimumSettlements({
  required Iterable<SettlementTransfer> obligations,
}) {
  final netByUserId = <String, int>{};

  for (final obligation in obligations) {
    if (obligation.payerUserId.isEmpty ||
        obligation.payeeUserId.isEmpty ||
        obligation.payerUserId == obligation.payeeUserId ||
        obligation.amountCents <= 0) {
      continue;
    }

    netByUserId[obligation.payerUserId] =
        (netByUserId[obligation.payerUserId] ?? 0) - obligation.amountCents;
    netByUserId[obligation.payeeUserId] =
        (netByUserId[obligation.payeeUserId] ?? 0) + obligation.amountCents;
  }

  final debtors = <_BalanceNode>[];
  final creditors = <_BalanceNode>[];

  netByUserId.forEach((userId, netCents) {
    if (netCents < 0) {
      debtors.add(_BalanceNode(userId: userId, amountCents: -netCents));
    } else if (netCents > 0) {
      creditors.add(_BalanceNode(userId: userId, amountCents: netCents));
    }
  });

  debtors.sort((a, b) => b.amountCents.compareTo(a.amountCents));
  creditors.sort((a, b) => b.amountCents.compareTo(a.amountCents));

  final minimized = <SettlementTransfer>[];
  var debtorIndex = 0;
  var creditorIndex = 0;

  while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
    final debtor = debtors[debtorIndex];
    final creditor = creditors[creditorIndex];
    final transfer = debtor.amountCents < creditor.amountCents
        ? debtor.amountCents
        : creditor.amountCents;

    if (transfer > 0) {
      minimized.add(
        SettlementTransfer(
          payerUserId: debtor.userId,
          payeeUserId: creditor.userId,
          amountCents: transfer,
        ),
      );
    }

    debtor.amountCents -= transfer;
    creditor.amountCents -= transfer;

    if (debtor.amountCents == 0) {
      debtorIndex++;
    }
    if (creditor.amountCents == 0) {
      creditorIndex++;
    }
  }

  return minimized;
}
