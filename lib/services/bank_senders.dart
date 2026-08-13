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
  ///
  /// IMPORTANT: Keep checks precise — many real bank messages contain words like
  /// "password", "code", etc. in a different context. Use full phrases or anchored
  /// patterns to avoid false positives that block legitimate unread notifications.
  static bool isSecurityOrAuthMessage(String? body) {
    if (body == null || body.trim().isEmpty) return false;
    final lower = body.toLowerCase();

    // ── Exact OTP / verification code patterns ───────────────────────────────
    if (lower.contains('one-time password')) return true;
    if (lower.contains('one time password')) return true;
    if (lower.contains('otp code')) return true;
    if (lower.contains('otp is')) return true;
    if (lower.contains('your otp')) return true;

    // ── PIN / password failure messages ──────────────────────────────────────
    if (lower.contains('pin or password is incorrect')) return true;
    if (lower.contains('incorrect pin')) return true;
    if (lower.contains('incorrect password')) return true;
    if (lower.contains('invalid pin')) return true;
    if (lower.contains('invalid password')) return true;
    if (lower.contains('wrong pin')) return true;
    if (lower.contains('wrong password')) return true;
    if (lower.contains('pin is incorrect')) return true;
    if (lower.contains('password is incorrect')) return true;

    // ── Reset / change requests ───────────────────────────────────────────────
    if (lower.contains('pin reset')) return true;
    if (lower.contains('password reset')) return true;
    if (lower.contains('reset your pin')) return true;
    if (lower.contains('reset your password')) return true;
    if (lower.contains('change your pin')) return true;
    if (lower.contains('change your password')) return true;

    // ── Auth codes — only when paired with OTP/auth context ──────────────────
    if (lower.contains('auth code')) return true;
    // "verification code" only when it looks like a code delivery (has digits nearby)
    if (lower.contains('verification code') &&
        RegExp(r'\d{4,8}').hasMatch(lower)) {
      return true;
    }
    // "access code" / "security code" — only when paired with OTP context
    if ((lower.contains('access code') || lower.contains('security code')) &&
        (lower.contains('use') || lower.contains('enter') || lower.contains('otp'))) {
      return true;
    }

    return false;
  }

}
