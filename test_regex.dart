import 'dart:core';

void main() {
  String message = '''Dear KALEB 
You have transferred ETB 5.00 to Yohannes Bizuneh (2519****6726) on 03/03/2026 15:55:23. Your transaction number is DC30DNNB8W. The service fee is  ETB 0.87 and  15% VAT on the service fee is ETB 0.13. Your current E-Money Account  balance is ETB 6.96. To download your payment information please click this link: https://transactioninfo.ethiotelecom.et/receipt/DC30DNNB8W.

Thank you for using telebirr
Ethio telecom''';

  String senderOrRecipient = '';
  final toMatch = RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
  if (toMatch != null) {
    senderOrRecipient = toMatch.group(1)?.trim() ?? '';
  }
  print('Result: $senderOrRecipient');
}
