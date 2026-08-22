import 'telebirr_parser.dart';

/// Decides whether an SMS genuinely originates from a trusted bank, based ONLY
/// on the sender address — never the message body.
///
/// This is what stops Shibre from recording a fake transaction when another
/// person types or forwards a real bank message (e.g. a CBE/Telebirr receipt)
/// from their own phone. Such a message arrives with the sender set to a normal
/// phone number, while genuine bank messages arrive from a registered
/// alphanumeric sender ID ("CBE", "Telebirr", "CBEBirr", "DashenBank") or Telebirr's "127"
/// short-code — IDs an ordinary user cannot send from.
class BankSenders {
  BankSenders._();

  /// Comprehensive list of standard bank sender search keywords used to query
  /// the native Android SMS provider without querying arbitrary personal messages.
  static const List<String> standardBankKeywords = [
    'telebirr',
    '127',
    'cbe',
    'cbebirr',
    'cbe birr',
    'ahadu',
    'boa',
    'abyssinia',
    'dashen',
    'amole',
    'wegagen',
    'oromia',
    'enat',
    'awash',
    'hibret',
    'nib',
    'zemen',
    'coop',
    'lion',
    'sinqe',
    'siinqee',
    'tsehay',
    'amhara',
    'bunna',
    'berhan',
    'global',
    'hijra',
    'zamzam',
  ];

  /// Phone numbers (7–15 digits, optional leading '+') belong to ordinary
  /// people, never to a bank's registered sender ID. Telebirr's "127" is only
  /// 3 digits, so it never matches this and stays valid below.
  static final RegExp _phoneNumber = RegExp(r'^\+?[0-9]{7,15}$');

  /// Returns the canonical bank name ('Telebirr' | 'CBE' | 'CBE Birr' | 'Ahadu Bank' | 'BOA' | 'Dashen Bank') when
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
    if (up == 'BOA' || up.contains('ABYSSINIA') || up.startsWith('BOA')) return 'BOA';
    if (up.contains('DASHEN') || up.contains('AMOLE')) return 'Dashen Bank';
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
    if (lower.contains('otp:')) return true;
    if (lower.contains('passcode')) return true;
    if (lower.contains('secret code')) return true;
    if (lower.contains('login code')) return true;
    if (lower.contains('activation code')) return true;
    if (lower.contains('confirmation code')) return true;

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
    if (lower.contains('pin locked') || lower.contains('password locked')) return true;
    if (lower.contains('account has been locked') || lower.contains('account locked')) return true;

    // ── Reset / change / credential delivery requests ─────────────────────────
    if (lower.contains('pin reset')) return true;
    if (lower.contains('pin is reset')) return true;
    if (lower.contains('password reset')) return true;
    if (lower.contains('reset your pin')) return true;
    if (lower.contains('reset your password')) return true;
    if (lower.contains('change your pin')) return true;
    if (lower.contains('change your password')) return true;
    if (lower.contains('pin changed') || lower.contains('password changed')) return true;
    if (lower.contains('pin code has been successfully changed')) return true;
    if (lower.contains('changed your telebirr pin')) return true;
    if (lower.contains('temporary pin') || lower.contains('temporary password')) return true;
    if (lower.contains('initial pin') || lower.contains('initial password')) return true;
    if (lower.contains('your pin is') || lower.contains('your password is') || lower.contains('new pin is')) return true;

    // ── Security warnings with PIN / code context ────────────────────────────
    if ((lower.contains('do not share') ||
            lower.contains('never share') ||
            lower.contains('do not disclose') ||
            lower.contains('keep it confidential') ||
            lower.contains('keep it secret')) &&
        (lower.contains('pin') ||
            lower.contains('otp') ||
            lower.contains('password') ||
            lower.contains('code'))) {
      return true;
    }

    // ── Auth codes — only when paired with OTP/auth context ──────────────────
    if (lower.contains('auth code')) return true;
    // "verification code" only when it looks like a code delivery (has digits nearby)
    if (lower.contains('verification code') &&
        RegExp(r'\d{4,8}').hasMatch(lower)) {
      return true;
    }
    // "access code" / "security code" — only when paired with OTP context
    if ((lower.contains('access code') || lower.contains('security code')) &&
        (lower.contains('use') || lower.contains('enter') || lower.contains('otp') || lower.contains('code'))) {
      return true;
    }

    // ── Amharic PIN / Password / Security / OTP patterns ─────────────────────
    if (lower.contains('የይለፍ ቃል') ||
        lower.contains('የይለፍ ቃልዎ') ||
        lower.contains('ሚስጥር ቁጥር') ||
        lower.contains('ሚስጥራዊ ቁጥር') ||
        lower.contains('የይለፍ ቁጥር') ||
        lower.contains('የማረጋገጫ ኮድ') ||
        lower.contains('የማረጋገጫ ቁጥር') ||
        (lower.contains('ኮድ') && (lower.contains('አይስጡ') || lower.contains('አያጋሩ')))) {
      return true;
    }

    return false;
  }

  /// Returns true if [body] is a non-transactional or informational message
  /// that should be completely auto-ignored and never saved as an unread notification:
  /// - PIN / OTP / Security messages
  /// - Loan / Credit / Sanduq contract notices & loan repayments
  /// - Inbound airtime gifts (SIM top-ups from other people)
  /// - Promotional points, lottery tickets, lucky draws, and marketing
  /// - ATM cash-out vouchers and OTP requests
  /// - Payment request prompts (pending / review prompts)
  /// - Cancellation and system error alerts
  /// - Account activation, status, and welcome notices
  static bool isIgnoredMessage(String? body) {
    if (body == null || body.trim().isEmpty) return false;
    final lower = body.toLowerCase();

    // 1. Security / OTP / PIN
    if (isSecurityOrAuthMessage(body)) return true;

    // 2. Loans / Credit / Sanduq contract notices, reminders & repayments
    if (lower.contains('outstanding credit') ||
        lower.contains('credit request with') ||
        lower.contains('credit limit') ||
        lower.contains('credit service') ||
        lower.contains('endekise service') ||
        lower.contains('ethiotel credit') ||
        lower.contains('telebirr mela') ||
        lower.contains('rmelaservice') ||
        lower.contains('loan balance') ||
        lower.contains('loan repayment') ||
        lower.contains('unpaid credit amount') ||
        lower.contains('repaid') ||
        lower.contains('penalty fee') ||
        lower.contains('facilitation fee')) {
      return true;
    }

    // 3. Inbound Airtime Gifts (SIM balance top-ups from other users)
    if (RegExp(r'(?:received|you received)\s+(?:etb\s+)?[0-9.,]+\s*(?:br\.?\s*)?airtime\s+from',
            caseSensitive: false)
        .hasMatch(lower) ||
        (lower.contains('received') && lower.contains('airtime from'))) {
      return true;
    }

    // 4. Marketing, Lottery, Points, Draws, KYC, Gift Letters
    if (lower.contains('lottery ticket') ||
        lower.contains('lottery id') ||
        lower.contains('received 1 point') ||
        lower.contains('received point') ||
        lower.contains('lucky draw') ||
        lower.contains('spins on superapp') ||
        lower.contains('kyc upgrade') ||
        lower.contains('won 1 gb') ||
        lower.contains('thank you lucky draw') ||
        lower.contains('chance to draw') ||
        lower.contains('chance(s) to draw') ||
        lower.contains('gift letter') ||
        lower.contains('yegena chewata') ||
        lower.contains('adey flowers') ||
        lower.contains('enkutatesh gift') ||
        lower.contains('enkutatash gift')) {
      return true;
    }

    // 5. ATM Cash-Out & Deposit Voucher codes / temporary invitations
    if (lower.contains('atm cash out') ||
        lower.contains('cash out voucher') ||
        lower.contains('voucher number is') ||
        lower.contains('deposit voucher code') ||
        lower.contains('voucher code is') ||
        lower.contains('secret word is') ||
        lower.contains('invitation code is') ||
        lower.contains('you have invited')) {
      return true;
    }

    // 6. Payment Requests (Pending / Prompt to review)
    if (lower.contains('payment request of') ||
        lower.contains('is requesting money on') ||
        lower.contains('please review and approve or reject')) {
      return true;
    }

    // 7. System Failures, Errors, Insufficient balance, Cancellations, Reversals
    if (lower.contains('is cancelled') ||
        lower.contains('has not been successful') ||
        lower.contains('was unsuccessful') ||
        lower.contains('fails to be sent') ||
        lower.contains('reversed to your account') ||
        lower.contains('processing failure response') ||
        lower.contains('insufficient balance for the requested transaction') ||
        lower.contains('is insufficient for the transaction') ||
        lower.contains('balance is insufficient to comp') ||
        lower.contains('wrong amount') ||
        lower.contains('account you try to transfer is not active') ||
        lower.contains('account you try to pay is not active')) {
      return true;
    }

    // 8. Account Activations & Welcome Notices
    if (lower.contains('saving service') ||
        lower.contains('customer status has been change') ||
        lower.contains('registered for mobile banking') ||
        lower.contains('register yourself for') ||
        lower.contains('account has been successfully activated') ||
        lower.contains('has been activated successfully') ||
        lower.contains('account is activated successfully') ||
        lower.contains('welcome! we are delighted') ||
        lower.contains('new login to your mobile')) {
      return true;
    }

    // 9. Informational balance breakdowns without transaction
    if (lower.contains('customer incentive account balance is') ||
        lower.contains('pocketmoneyaccount balance is')) {
      return true;
    }

    return false;
  }
}
