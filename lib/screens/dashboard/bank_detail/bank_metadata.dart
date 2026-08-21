import 'package:flutter/material.dart';
import '../../../widgets/bank_card_widget.dart';
import 'bank_behind_info_panel.dart';

class BankInfoData {
  final String bankName;
  final String displayName;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData badgeIcon;
  final String description;
  final List<Color> behindGradient;
  final bool isDarkTextTheme;

  const BankInfoData({
    required this.bankName,
    required this.displayName,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeIcon,
    required this.description,
    required this.behindGradient,
    required this.isDarkTextTheme,
  });

  static BankInfoData forBank(String name) {
    final nameUp = name.toUpperCase().trim();
    final isDark = BankCardWidget.isDarkTextTheme(name);
    const unifiedGradient = BankBehindInfoPanel.primaryGradient;

    if (nameUp == 'CASH WALLET') {
      return const BankInfoData(
        bankName: 'Cash Wallet',
        displayName: 'Cash Wallet',
        title: 'Physical Cash in Hand',
        subtitle: 'Physical Cash Tracking',
        badgeLabel: 'CASH IN HAND',
        badgeIcon: Icons.bolt_rounded,
        description:
            'Manage and track physical cash transactions outside bank networks. ATM cash withdrawals automatically credit this balance, while offline spending and custom expense templates can be logged directly.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: false,
      );
    } else if (nameUp == 'LOAN TRACKER' || nameUp == 'LOANS' || nameUp == 'LOAN') {
      return const BankInfoData(
        bankName: 'Loan Tracker',
        displayName: 'Loan Tracker',
        title: 'Personal Debt & Loan Ledger',
        subtitle: 'Peer-to-peer Lending & Borrowing',
        badgeLabel: 'DEBT & CREDIT TRACKER',
        badgeIcon: Icons.handshake_rounded,
        description:
            'Track personal loans lent to friends/contacts and debts owed. Automatically handles partial repayments, interest/repayment schedules, approval requests, and settlement tracking with SMS receipt linking.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: false,
      );
    } else if (nameUp == 'TELEBIRR') {
      return BankInfoData(
        bankName: name,
        displayName: 'Telebirr',
        title: 'Ethio Telecom Mobile Money',
        subtitle: 'Ethio Telecom , E- money',
        badgeLabel: 'E-MONEY · SMS PARSED',
        badgeIcon: Icons.bolt_rounded,
        description:
            'Real-time automated extraction of Telebirr transfer receipts, airtime recharges, package subscriptions, and Sanduq savings from official 127 SMS broadcasts. Tracks live wallet and savings balances.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: isDark,
      );
    } else if (nameUp == 'CBE') {
      return BankInfoData(
        bankName: name,
        displayName: 'Commercial Bank of Ethiopia',
        title: 'Commercial Bank of Ethiopia',
        subtitle: 'Commercial Bank of Ethiopia',
        badgeLabel: 'STATE BANK · SMS PARSED',
        badgeIcon: Icons.account_balance_rounded,
        description:
            'Automated transaction processing and ledger reconciliation from CBE 6061 SMS notifications. Captures account debits, deposit credits, and post-transaction account balance updates.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: isDark,
      );
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return BankInfoData(
        bankName: name,
        displayName: 'CBE Birr',
        title: 'CBE Birr Mobile Wallet',
        subtitle: 'CBE Birr Mobile Wallet',
        badgeLabel: 'MOBILE WALLET · SMS PARSED',
        badgeIcon: Icons.phone_android_rounded,
        description:
            'Instant tracking of CBE Birr wallet payments, merchant transactions, agent cash-ins, and peer transfers received via official CBE Birr service notifications.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: isDark,
      );
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      return BankInfoData(
        bankName: name,
        displayName: 'Bank of Abyssinia',
        title: 'Bank of Abyssinia S.C.',
        subtitle: 'Bank of Abyssinia S.C.',
        badgeLabel: 'PRIVATE BANK · SMS PARSED',
        badgeIcon: Icons.account_balance_rounded,
        description:
            'Direct extraction of banking transaction receipts from Bank of Abyssinia SMS notifications. Tracks account debits, deposits, and confirmed available balance amounts.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: isDark,
      );
    } else if (nameUp.contains('AHADU')) {
      return BankInfoData(
        bankName: name,
        displayName: 'Ahadu Bank',
        title: 'Ahadu Bank S.C.',
        subtitle: 'Ahadu Bank S.C.',
        badgeLabel: 'COMMERCIAL BANK · SMS PARSED',
        badgeIcon: Icons.account_balance_rounded,
        description:
            'Automated parsing of Ahadu Bank transaction notifications. Captures fund transfers, digital banking expenses, credit receipts, and real-time ledger balance updates.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: isDark,
      );
    } else if (nameUp.contains('DASHEN')) {
      return BankInfoData(
        bankName: name,
        displayName: 'Dashen Bank',
        title: 'Dashen Bank S.C.',
        subtitle: 'Dashen Bank S.C.',
        badgeLabel: 'COMMERCIAL BANK · SMS PARSED',
        badgeIcon: Icons.account_balance_rounded,
        description:
            'Automated ledger tracking from Dashen Bank SMS notifications. Captures Amole & digital banking income, expenses, ATM withdrawals, and current balances.',
        behindGradient: unifiedGradient,
        isDarkTextTheme: isDark,
      );
    }

    // Generic fallback
    return BankInfoData(
      bankName: name,
      displayName: name,
      title: BankCardWidget.subtitle(name),
      subtitle: BankCardWidget.subtitle(name),
      badgeLabel: 'BANK ACCOUNT · SMS PARSED',
      badgeIcon: Icons.account_balance_rounded,
      description:
          'Automated transaction processing and financial tracking for $name. Transaction SMS notifications are parsed into structured ledger records with real-time balance tracking.',
      behindGradient: unifiedGradient,
      isDarkTextTheme: isDark,
    );
  }
}
