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

  /// Returns true if [body] is a password, PIN, authentication failure, or security
  /// verification message (e.g. "Sorry, your PIN or password is incorrect", OTP codes,
  /// PIN reset notifications) that should be auto-ignored and never saved into Shibre.
  static bool isSecurityOrAuthMessage(String? body) {
    if (body == null || body.trim().isEmpty) return false;
    final lower = body.toLowerCase();
    return lower.contains('password') ||
        lower.contains('pin or password') ||
        lower.contains('incorrect pin') ||
        lower.contains('incorrect password') ||
        lower.contains('invalid pin') ||
        lower.contains('invalid password') ||
        lower.contains('wrong pin') ||
        lower.contains('wrong password') ||
        lower.contains('pin is incorrect') ||
        lower.contains('password is incorrect') ||
        lower.contains('one-time password') ||
        lower.contains('verification code') ||
        lower.contains('otp code') ||
        lower.contains('pin reset') ||
        lower.contains('password reset') ||
        lower.contains('access code') ||
        lower.contains('security code') ||
        lower.contains('auth code');
  }
}
