import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../dashboard/sender_detail_screen.dart';
import '../dashboard/cash_wallet_detail_screen.dart';
import 'freeze_account_sheet.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final senders = provider.senders;
    final txs = provider.transactions;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.screenBackgroundGradient,
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header Title & Add New Button ─────────────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Accounts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Add New Wallet feature coming soon!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  color: AppColors.background,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Add New',
                                  style: TextStyle(
                                    color: AppColors.background,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Wallet Cards List ─────────────────────────────────────────
              senders.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.textSecondary.withValues(alpha: 0.4),
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No wallets connected yet',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Set up senders in Settings to get started',
                              style: TextStyle(
                                  color: AppColors.textSoft, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == senders.length) {
                              return _buildCashWalletRow(context, provider);
                            }

                            final sender = senders[index];
                            final senderTxs = txs
                                .where((t) => t.name == sender.senderName)
                                .toList();

                            double balance = 0;
                            final withBal =
                                senderTxs.where((t) => t.totalBalance > 0);
                            if (withBal.isNotEmpty) {
                              balance = withBal.first.totalBalance;
                            }

                            return _WalletCard(
                              senderName: sender.senderName,
                              balance: balance,
                              txCount: senderTxs.length,
                              isBalanceVisible: provider.isBalanceVisible,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SenderDetailScreen(sender: sender),
                                ),
                              ),
                            );
                          },
                          childCount: senders.length + 1,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashWalletRow(BuildContext context, FinanceProvider provider) {
    int txCount = 0;

    for (var tx in provider.transactions) {
      if (tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash') {
        txCount++;
      }
    }
    txCount += provider.cashTransactions.length;

    return _WalletCard(
      senderName: 'Cash Wallet',
      balance: provider.cashBalance,
      txCount: txCount,
      isBalanceVisible: provider.isBalanceVisible,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CashWalletDetailScreen(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Minimal Minimal Bank Card Component
// ─────────────────────────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final VoidCallback onTap;

  const _WalletCard({
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.onTap,
  });

  Widget _bankLogo(String name) {
    final nameUp = name.toUpperCase();
    String imagePath = '';

    if (nameUp == 'CBE') {
      imagePath = 'assets/images/CBE logo 1.png';
    } else if (nameUp == 'TELEBIRR') {
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      imagePath = 'assets/images/CBEBirr Logo.png';
    } else if (nameUp.contains('AHADU')) {
      imagePath = 'assets/images/Ahadu_Logo.png';
    }

    if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        width: 38,
        height: 38,
        fit: BoxFit.contain,
      );
    }

    if (nameUp == 'CASH WALLET') {
      return const Icon(
        Icons.account_balance_wallet_outlined,
        color: Colors.white,
        size: 34,
      );
    }

    return Icon(
      Icons.account_balance,
      color: Colors.white.withValues(alpha: 0.9),
      size: 34,
    );
  }

  String _subtitle(String name) {
    final n = name.toUpperCase();
    if (n == 'TELEBIRR') return 'Ethio Telecom , E- money';
    if (n == 'CBE') return 'Commercial Bank of Ethiopia';
    if (n == 'CBE BIRR' || n == 'CBEBIRR') return 'CBE Birr Mobile Wallet';
    if (n.contains('AHADU')) return 'Ahadu Bank S.C.';
    if (n == 'CASH WALLET') return 'Physical Cash Tracking';
    return 'Bank Account';
  }

  List<Color> _getCardGradient(String name) {
    final nameUp = name.toUpperCase();
    if (nameUp == 'TELEBIRR') {
      return [
        AppColors.success,
        AppColors.cardLime,
      ];
    } else if (nameUp == 'CBE') {
      return [
        AppColors.cardBrownDark,
        AppColors.cardBrownMid,
      ];
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return [
        AppColors.cardCbeBirrSilver,
        AppColors.cardCbeBirrWhite,
      ];
    } else if (nameUp.contains('AHADU')) {
      return [
        AppColors.cardAhaduPink,
        AppColors.cardAhaduWhite,
      ];
    } else if (nameUp == 'CASH WALLET') {
      return [
        AppColors.cardGrayDark,
        AppColors.cardGrayMid,
      ];
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA') {
      return [
        AppColors.cardBoaDarkIcon,
        AppColors.cardBoaBg,
      ];
    } else if (nameUp.contains('DASHEN')) {
      return [
        AppColors.cardDashenDarkIcon,
        AppColors.cardDashenBg,
      ];
    } else if (nameUp.contains('COOP')) {
      return [
        AppColors.cardCoopDarkIcon,
        AppColors.cardCoopBg,
      ];
    }
    return [
      AppColors.bgMid,
      AppColors.cardGrayLight,
    ];
  }



  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final fmt = NumberFormat('#,##0.00');
    final balStr = isBalanceVisible ? fmt.format(balance) : '****,***.**';
    final parts = balStr.split('.');
    final cardGradient = _getCardGradient(senderName);

    final bool isDarkTextTheme = senderName.toUpperCase().contains('AHADU') ||
        senderName.toUpperCase() == 'CBE BIRR' ||
        senderName.toUpperCase() == 'CBEBIRR';
    final Color textColorPrimary = isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);

    final pageOffset = provider.pageOffset;
    final t = pageOffset.clamp(0.0, 1.0);

    final String nameUp = senderName.toUpperCase();
    final bool isPrimaryStackedCard = nameUp == 'TELEBIRR' ||
        nameUp == 'CBE' ||
        nameUp == 'CBE BIRR' ||
        nameUp == 'CBEBIRR';

    // Hide static list cards during physical card flight transition
    if (isPrimaryStackedCard && t > 0.001 && t < 0.999) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 160,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
      );
    }

    final double cardOpacity;
    final double scale;
    final double translateY;

    if (isPrimaryStackedCard) {
      cardOpacity = (t * 1.6 - 0.1).clamp(0.0, 1.0);
      scale = lerpDouble(0.85, 1.0, t)!;
      translateY = lerpDouble(-20 * (1 - t), 0, t)!;
    } else {
      cardOpacity = (t * 2.2 - 1.2).clamp(0.0, 1.0);
      scale = lerpDouble(0.9, 1.0, t)!;
      translateY = lerpDouble(35 * (1 - t), 0, t)!;
    }

    return Hero(
      tag: 'hero_card_$nameUp',
      child: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: cardOpacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: cardGradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cardGradient.first.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Logo + Bank Title + Sub-description
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _bankLogo(senderName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  senderName.toUpperCase().contains('AHADU')
                                      ? 'Ahadu Bank'
                                      : senderName,
                                  style: TextStyle(
                                    color: textColorPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _subtitle(senderName),
                                  style: TextStyle(
                                    color: textColorSub,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Large Balance Display (Integer + Decimals)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            parts[0],
                            style: TextStyle(
                              color: textColorPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '.${parts[1]}',
                            style: TextStyle(
                              color: isDarkTextTheme
                                  ? AppColors.darkCharcoal.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.65),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Subtitle: Transaction Count
                      Text(
                        '$txCount total Transactions',
                        style: TextStyle(
                          color: textColorSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Glassmorphic Ice Freeze Account Button Component (Excluding Cash Wallet)
                      if (senderName.toUpperCase() != 'CASH WALLET')
                        _FreezeAccountGlassButton(
                          senderName: senderName,
                          balance: balance,
                          txCount: txCount,
                          isBalanceVisible: isBalanceVisible,
                          isDarkTextTheme: isDarkTextTheme,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Glassmorphic Ice Freeze Account Button Component
// ─────────────────────────────────────────────────────────────────────────────
class _FreezeAccountGlassButton extends StatelessWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isDarkTextTheme;

  const _FreezeAccountGlassButton({
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isDarkTextTheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FreezeAccountBottomSheet.show(
          context,
          senderName: senderName,
          balance: balance,
          txCount: txCount,
          isBalanceVisible: isBalanceVisible,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDarkTextTheme
              ? AppColors.darkCharcoal.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkTextTheme
                ? AppColors.darkCharcoal.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ac_unit,
              color: isDarkTextTheme
                  ? AppColors.darkCharcoal
                  : Colors.white,
              size: 12,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Freeze Account',
                    style: TextStyle(
                      color: isDarkTextTheme
                          ? AppColors.darkCharcoal
                          : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'MAKE APP NOT READ THIS ACC',
                    style: TextStyle(
                      color: isDarkTextTheme
                          ? AppColors.darkCharcoal.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 5.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
