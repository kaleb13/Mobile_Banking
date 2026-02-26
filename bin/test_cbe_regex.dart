// ignore_for_file: avoid_print
import 'package:mobile_banking_app/services/cbe_parser.dart';

void main() {
  String msg =
      '''Dear Kaleb, You have transfered ETB 2.00 to Miss Bethelihem on 22/02/2026 at 18:21:11 from your account 1*********2757. Your account has been debited with a S.charge of ETB 0.50 and  15% VAT of ETB0.08, with a total of ETB 2.58. Your Current Balance is ETB 2,273.46. Thank you for Banking with CBE! https://apps.cbe.com.et:100/?id=FT2605360FYH17182757 For feedback click the link https://forms.gle/R1s9nkJ6qZVCxRVu9''';

  var res = CbeParser.parse(msg, DateTime.now());
  print(res?.toMap());
}
