import 'package:url_launcher/url_launcher.dart';

class UpiDeepLink {
  static const String fallbackUpiId = 'kunjshah2112@okicici';

  static Uri buildUpiUri({
    required String receiverName,
    required double amount,
    String? recipientUpiId,
    String? note,
    String? transactionRef,
    String? callbackUrl,
  }) {
    final upiId = (recipientUpiId ?? '').trim().isEmpty
        ? fallbackUpiId
        : recipientUpiId!.trim();

    final query = <String, String>{
      'pa': upiId,
      'pn': receiverName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': (note ?? 'SpliTease payment').trim(),
    };

    if ((transactionRef ?? '').trim().isNotEmpty) {
      query['tr'] = transactionRef!.trim();
    }

    if ((callbackUrl ?? '').trim().isNotEmpty) {
      query['url'] = callbackUrl!.trim();
    }

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: query,
    );
  }

  static Future<bool> launchUpiPayment({
    required String receiverName,
    required double amount,
    String? recipientUpiId,
    String? note,
    String? transactionRef,
    String? callbackUrl,
  }) async {
    final upiUri = buildUpiUri(
      receiverName: receiverName,
      amount: amount,
      recipientUpiId: recipientUpiId,
      note: note,
      transactionRef: transactionRef,
      callbackUrl: callbackUrl,
    );

    return launchUrl(upiUri, mode: LaunchMode.externalApplication);
  }
}
