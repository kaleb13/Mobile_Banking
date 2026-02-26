import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:math';
import 'dart:ui';
import 'sender_detail_screen.dart';
import 'transaction_detail_screen.dart';
import 'notifications_screen.dart';
import 'reason_management_screen.dart';
import 'all_transactions_screen.dart';
import 'settings_screen.dart';
import '../loans/loan_management_screen.dart';

import 'package:flutter_svg/flutter_svg.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isMenuOpen = false;

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0B0D),
          body: Stack(
            children: [
              _buildMenuLayer(context),
              _buildMainDashboardLayout(context),
            ],
          ),
        ));
  }

  // ─── Side Menu ────────────────────────────────────────────────────────────
  Widget _buildMenuLayer(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 24.0, top: 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D739F),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shibre',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Spend With Awareness.',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 64),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppColors.textWhite),
              title: const Text('Setting',
                  style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
              onTap: () {
                _toggleMenu();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.help_outline, color: AppColors.textWhite),
              title: const Text('Reason',
                  style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
              onTap: () {
                _toggleMenu();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReasonManagementScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined,
                  color: AppColors.textWhite),
              title: const Text('Loans',
                  style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
              onTap: () {
                _toggleMenu();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoanManagementScreen()),
                );
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ─── Main Layout ──────────────────────────────────────────────────────────
  Widget _buildMainDashboardLayout(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: _isMenuOpen ? _toggleMenu : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.centerLeft,
        transform: Matrix4.translationValues(
          _isMenuOpen ? screenWidth * 0.52 : 0.0,
          _isMenuOpen ? 120.0 : 0.0,
          0.0,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0B0D),
          borderRadius:
              _isMenuOpen ? BorderRadius.circular(40) : BorderRadius.zero,
          border: _isMenuOpen
              ? Border.all(color: const Color(0xFF0D282A), width: 2)
              : Border.all(color: Colors.transparent, width: 0),
          boxShadow: _isMenuOpen
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius:
              _isMenuOpen ? BorderRadius.circular(38) : BorderRadius.zero,
          child: AbsorbPointer(
            absorbing: _isMenuOpen,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0.0, end: _isMenuOpen ? 1.0 : 0.0),
              builder: (context, value, child) {
                return ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: value * 4.5,
                    sigmaY: value * 4.5,
                  ),
                  child: Container(
                    foregroundDecoration: BoxDecoration(
                      color: const Color(0xFF0D739F)
                          .withValues(alpha: value * 0.45),
                    ),
                    child: child,
                  ),
                );
              },
              child: Scaffold(
                extendBody: true,
                backgroundColor: const Color(0xFF0A0B0D),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top gradient section
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0.0, -1.0),
                          radius: 0.95,
                          colors: [
                            AppColors.accentBlue,
                            AppColors.primaryBlue,
                            Color(0xFF0A0B0D),
                          ],
                          stops: [0.0, 0.40, 0.95],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            const SizedBox(height: 32),
                            _buildHeader(context),
                            const SizedBox(height: 24),
                            _buildBalanceCard(context),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSendersList(context),
                    const SizedBox(height: 16),
                    Expanded(child: _buildTransactionsList(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu + greeting
          Row(
            children: [
              GestureDetector(
                onTap: _toggleMenu,
                child: SvgPicture.asset(
                  'assets/images/Menu.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textWhite, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style:
                        const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
                  ),
                  const Text(
                    'Shibre',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Search + Bell
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search,
                    color: AppColors.textWhite, size: 18),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_none,
                          color: AppColors.textWhite, size: 20),
                    ),
                    if (provider.unreadNotificationCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppColors.alertRed,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${provider.unreadNotificationCount > 9 ? '9+' : provider.unreadNotificationCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Balance Card ─────────────────────────────────────────────────────────
  Widget _buildBalanceCard(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatter = NumberFormat('#,##0.00');
    final String fullyFormatted = provider.isBalanceVisible
        ? formatter.format(provider.totalBalance)
        : '****.**';
    final parts = fullyFormatted.split('.');

    return Column(
      children: [
        // "Your total balance" label
        const Text(
          'Your total balance',
          style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
        ),
        const SizedBox(height: 8),
        // Tap the balance to toggle visibility
        GestureDetector(
          onTap: provider.toggleBalanceVisibility,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                parts[0],
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 48,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                ),
              ),
              Text(
                '.${parts[1]}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.33),
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // % and net
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              provider.incomePercentageChange >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: provider.incomePercentageChange >= 0
                  ? AppColors.mintGreen
                  : AppColors.alertRed,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              '${provider.incomePercentageChange.toStringAsFixed(0)}%',
              style: TextStyle(
                color: provider.incomePercentageChange >= 0
                    ? AppColors.mintGreen
                    : AppColors.alertRed,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${provider.netForSelectedDate >= 0 ? '+' : ''}${NumberFormat('#,##0').format(provider.netForSelectedDate)})',
              style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 22),
        // Expense Overview button
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.textWhite,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_double_arrow_right,
                    color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text(
                  'Expense Overview',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Wallets / Senders List ───────────────────────────────────────────────
  Widget _buildSendersList(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final senders = provider.senders;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'All Wallets',
                style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w400),
              ),
              Text(
                'View All',
                style: TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: senders.length,
            itemBuilder: (context, index) {
              final sender = senders[index];
              final bool isLast = index == senders.length - 1;

              // Latest balance from transactions
              double senderBalance = 0;
              final matchingTxs = provider.transactions.where(
                  (t) => t.name == sender.senderName && t.totalBalance > 0);
              if (matchingTxs.isNotEmpty) {
                senderBalance = matchingTxs.first.totalBalance;
              }

              // Today's net
              final now = DateTime.now();
              double totalNet = 0;
              for (var tx in provider.transactions) {
                if (tx.name == sender.senderName &&
                    tx.date.year == now.year &&
                    tx.date.month == now.month &&
                    tx.date.day == now.day) {
                  if (tx.type == 'income') totalNet += tx.amount;
                  if (tx.type == 'expense') totalNet -= tx.amount;
                }
              }
              final String sign = totalNet >= 0 ? '+' : '';
              double percentChange =
                  senderBalance > 0 ? (totalNet / senderBalance) * 100 : 0;

              String subTitle = '';
              final nameUp = sender.senderName.toUpperCase();
              if (nameUp == 'CBE') subTitle = 'Mobile Banking';
              if (nameUp == 'TELEBIRR') subTitle = 'E-money';
              if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
                subTitle = 'Mobile Wallet';
              }

              final fmt = NumberFormat('#,##0.00');
              final fmtStr = fmt.format(senderBalance);
              final fparts = fmtStr.split('.');

              // Circular avatar
              Widget logoWidget;
              if (nameUp == 'CBE') {
                logoWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/images/CBE.png',
                      width: 36, height: 36, fit: BoxFit.cover),
                );
              } else if (nameUp == 'TELEBIRR') {
                logoWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/images/Telebirr.png',
                      width: 36, height: 36, fit: BoxFit.cover),
                );
              } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
                logoWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/images/CBEBirr.png',
                      width: 36, height: 36, fit: BoxFit.cover),
                );
              } else {
                logoWidget = Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceDark,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      sender.senderName
                          .substring(0, min(3, sender.senderName.length))
                          .toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.textGray, fontSize: 11),
                    ),
                  ),
                );
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SenderDetailScreen(sender: sender),
                    ),
                  );
                },
                child: Container(
                  width: 158,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  margin: EdgeInsets.only(right: isLast ? 0 : 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF161616),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + name
                      Row(
                        children: [
                          logoWidget,
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sender.senderName,
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subTitle.isNotEmpty)
                                  Text(
                                    subTitle,
                                    style: const TextStyle(
                                        color: AppColors.textGray, fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Balance
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            fparts[0],
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '.${fparts[1]}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.33),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // % and amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                totalNet >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: totalNet >= 0
                                    ? AppColors.mintGreen
                                    : AppColors.alertRed,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${percentChange.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: totalNet >= 0
                                      ? AppColors.mintGreen
                                      : AppColors.alertRed,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$sign${NumberFormat('#,##0').format(totalNet)}',
                            style: const TextStyle(
                                color: AppColors.textGray, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Transactions List ────────────────────────────────────────────────────
  Widget _buildTransactionsList(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final transactions = provider.transactionsForSelectedDate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transactions',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (provider.isShowingAll) {
                        provider.setSelectedDate(DateTime.now());
                      } else {
                        provider.setShowingAll();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        provider.isShowingAll ? 'Today' : 'All Transactions',
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllTransactionsScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(color: AppColors.textGray, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 2.0, bottom: 100.0),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];

                // Impact percent
                double impactPercent = 0;
                if (provider.totalBalance > 0) {
                  impactPercent = (tx.amount / provider.totalBalance) * 100;
                }

                // Bank avatar
                Widget avatar;
                final nameUp = tx.name.toUpperCase();
                if (nameUp == 'CBE') {
                  avatar = ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/images/CBE.png',
                        width: 44, height: 44, fit: BoxFit.cover),
                  );
                } else if (nameUp == 'TELEBIRR') {
                  avatar = ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/images/Telebirr.png',
                        width: 44, height: 44, fit: BoxFit.cover),
                  );
                } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
                  avatar = ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/images/CBEBirr.png',
                        width: 44, height: 44, fit: BoxFit.cover),
                  );
                } else {
                  avatar = Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceDark,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        tx.name
                            .substring(0, min(3, tx.name.length))
                            .toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.textGray, fontSize: 12),
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TransactionDetailScreen(transaction: tx),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC7C7C7).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        // Left: title + sender
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tx.type == 'income'
                                        ? 'Deposit'
                                        : 'Transferred',
                                    style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  if (index == 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.alertRed,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('NEW',
                                          style: TextStyle(
                                              color: AppColors.textWhite,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  if (tx.resolvedReason == null)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('REASON?',
                                          style: TextStyle(
                                              color: AppColors.textWhite,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${tx.type == 'income' ? 'From' : 'For'} ${tx.sender}',
                                style: const TextStyle(
                                    color: AppColors.textGray, fontSize: 9),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Right: amount + trending %
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Builder(builder: (context) {
                              final String amountStr =
                                  NumberFormat('#,##0.00').format(tx.amount);
                              final amountParts = amountStr.split('.');
                              return Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '${tx.type == 'income' ? '+' : '-'}${amountParts[0]}',
                                      style: const TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '.${amountParts[1]}',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.33),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  tx.type == 'income'
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: tx.type == 'income'
                                      ? AppColors.mintGreen
                                      : AppColors.alertRed,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${impactPercent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: tx.type == 'income'
                                        ? AppColors.mintGreen
                                        : AppColors.alertRed,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
