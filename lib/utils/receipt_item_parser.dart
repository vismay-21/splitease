class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.amount,
  });

  final String name;
  final double amount;
}

class ReceiptItemParser {
  ReceiptItemParser._();

  static final RegExp _lineEndingAmountRegex = RegExp(
    r'^(.+?)\s+([0-9]+(?:[\.,][0-9]{1,2})?)$',
  );
  static final RegExp _amountOnlyRegex = RegExp(
    r'^(?:rs\.?|inr|\u20b9)?\s*([0-9]+(?:[\.,][0-9]{1,2})?)\s*$',
    caseSensitive: false,
  );

  static final List<String> _blockedKeywords = <String>[
    'total',
    'subtotal',
    'sub total',
    'grand total',
    'amount due',
    'net amount',
    'tax',
    'gst',
    'sgst',
    'cgst',
    'service charge',
    'discount',
    'cash',
    'change',
    'round off',
    'invoice',
    'table',
    'phone',
    'mob',
    'mobile',
    'gstin',
    'date',
    'upi',
    'payment',
  ];

  // Anything over ₹50 000 is almost certainly a pincode / phone number, not a price.
  static const double _maxReasonableAmount = 50000;

  static List<ReceiptLineItem> extractItems(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final strictItems = <ReceiptLineItem>[];

    for (final line in lines) {
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ');
      final lower = normalized.toLowerCase();

      if (_blockedKeywords.any(lower.contains)) {
        continue;
      }

      final match = _lineEndingAmountRegex.firstMatch(normalized);
      if (match == null) {
        continue;
      }

      var name = (match.group(1) ?? '').trim();
      var amountRaw = (match.group(2) ?? '').trim();
      amountRaw = amountRaw.replaceAll(',', '.');

      final amount = double.tryParse(amountRaw);
      if (amount == null || amount <= 0 || amount >= _maxReasonableAmount) {
        continue;
      }

      name = name.replaceAll(RegExp(r'^[^A-Za-z0-9]+'), '').trim();
      if (name.length < 2) {
        continue;
      }

      strictItems.add(ReceiptLineItem(name: name, amount: amount));
    }

    if (strictItems.isNotEmpty) {
      return strictItems.length > 25 ? strictItems.take(25).toList() : strictItems;
    }

    final fallbackItems = <ReceiptLineItem>[];

    for (var i = 0; i < lines.length; i++) {
      final normalized = lines[i].replaceAll(RegExp(r'\s+'), ' ');
      final lower = normalized.toLowerCase();

      if (_blockedKeywords.any(lower.contains)) {
        continue;
      }

      final amountOnlyMatch = _amountOnlyRegex.firstMatch(normalized);
      if (amountOnlyMatch == null) {
        continue;
      }

      final amountRaw = (amountOnlyMatch.group(1) ?? '').replaceAll(',', '.');
      final amount = double.tryParse(amountRaw);
      if (amount == null || amount <= 0 || amount >= _maxReasonableAmount) {
        continue;
      }

      var inferredName = _neighborName(lines, i - 1);
      inferredName ??= _neighborName(lines, i + 1);
      inferredName ??= 'Item ${fallbackItems.length + 1}';

      fallbackItems.add(ReceiptLineItem(name: inferredName, amount: amount));
    }

    if (fallbackItems.length > 25) {
      return fallbackItems.take(25).toList();
    }

    if (fallbackItems.isNotEmpty) {
      return fallbackItems;
    }

    return <ReceiptLineItem>[];
  }

  static String? _neighborName(List<String> lines, int index) {
    if (index < 0 || index >= lines.length) {
      return null;
    }

    var candidate = lines[index].replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = candidate.toLowerCase();
    if (_blockedKeywords.any(lower.contains)) {
      return null;
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(candidate)) {
      return null;
    }

    candidate = candidate.replaceAll(RegExp(r'^[^A-Za-z0-9]+'), '').trim();
    if (candidate.length < 2) {
      return null;
    }

    return candidate;
  }
}