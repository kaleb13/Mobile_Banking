// ignore_for_file: avoid_print
import 'package:mobile_banking_app/services/telebirr_parser.dart';

void main() {
  String msg =
      '''Your telebirr account 251972665987 has been debited with ETB 70.00 on 05/03/2026 19:19:48 at telebirr Agent 248168. Your transaction number is DC58GKNESW. The service fee is  ETB 2.40 and  15% VAT on the service fee is ETB 0.36. Your current Account balance is ETB 934.20. To download your payment information please click this link: https://transactioninfo.ethiotelecom.et/receipt/DC58GKNESW
Thank you for using telebirr
Ethio telecom''';

  var res = TelebirrParser.parse(msg, DateTime.now());
  print(res?.toMap());
}
