import 'telebirr_parser.dart';

/// Decides whether an SMS genuinely originates from a trusted bank, based ONLY
/// on the sender address — never the message body.
///
/// This is what stops Shibre from recording a fake transaction when another
/// person types or forwards a real bank message (e.g. a CBE/Telebirr receipt)
/// from their own phone. Such a message arrives with the sender set to a normal
/// phone number, while genuine bank messages arrive from a registered
/// alphanumeric sender ID ("CBE", "Telebirr", "CBEBirr") or Telebirr's "127"
/// short-code — IDs an ordinary user cannot send from.
class BankSenders {
  BankSenders._();

  /// Phone numbers (7–15 digits, optional leading '+') belong to ordinary
  /// people, never to a bank's registered sender ID. Telebirr's "127" is only
  /// 3 digits, so it never matches this and stays valid below.
  static final RegExp _phoneNumber = RegExp(r'^\+?[0-9]{7,15}$');

  /// Returns the canonical bank name ('Telebirr' | 'CBE' | 'CBE Birr') when
  /// [sender] is a trusted bank sender ID, otherwise null.
  static String? match(String? sender) {
    if (sender == null) return null;
    final s = sender.trim();
    if (s.isEmpty) return null;

    // Reject ordinary phone-number senders outright (a person, not a bank).
    if (_phoneNumber.hasMatch(s) && s != TelebirrParser.senderNumber) {
      return null;
    }

    final up = s.toUpperCase();
    if (up.contains('TELEBIRR') || s == TelebirrParser.senderNumber) {
      return 'Telebirr';
    }
    if (up.contains('CBE') && up.contains('BIRR')) return 'CBE Birr';
    if (up.contains('CBE')) return 'CBE';
    if (up.contains('AHADU')) return 'Ahadu Bank';
    return null;
  }
}
