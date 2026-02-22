import 'package:mobile_banking_app/services/telebirr_parser.dart';

void main() {
  String msg = '''Dear KALEB 
You have received ETB 55.00 from Amanuel Mandefro(2519****1346) 101305 on 20/02/2026 13:46:52. Your transaction number is DBK816C4VE. Your current E-Money Account balance is ETB 55.96.
Thank you for using telebirr
Ethio telecom''';

  var res = TelebirrParser.parse(msg, DateTime.now());
  print(res?.toMap());
}
