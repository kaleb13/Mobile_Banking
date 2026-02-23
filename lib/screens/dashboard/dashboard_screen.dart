import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:math';
import 'sender_detail_screen.dart';
import 'transaction_detail_screen.dart';
import 'notifications_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // White text/icons
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.3, 0.6),
                    radius: 1.1,
                    colors: [
                      Color(0xFF0C393C),
                      Color(0xFF0F0F0F),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildHeader(context),
                      const SizedBox(height: 28),
                      _buildBalanceCard(context),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSendersList(context),
              const SizedBox(height: 16),
              Expanded(child: _buildTransactionsList(context)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              // Manual add transaction action
            },
            backgroundColor: AppColors.surfaceLight,
            child: const Icon(Icons.add, color: AppColors.textWhite),
          ),
        ));
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/images/Menu.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textWhite, BlendMode.srcIn)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                        color: AppColors.textGray, fontSize: 13),
                  ),
                  const Text(
                    'User',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                SvgPicture.asset(
                  'assets/images/Notification.svg',
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textWhite, BlendMode.srcIn),
                ),
                if (provider.unreadNotificationCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.alertRed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${provider.unreadNotificationCount > 9 ? '9+' : provider.unreadNotificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatter = NumberFormat('#,##0.00');
    final String fullyFormatted = provider.isBalanceVisible
        ? formatter.format(provider.totalBalance)
        : '****.**';
    final parts = fullyFormatted.split('.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your total balance',
            style: TextStyle(color: AppColors.textGray, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    parts[0],
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 48,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '.${parts[1]}',
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: provider.toggleBalanceVisibility,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    provider.isBalanceVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textGray,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${provider.incomePercentageChange > 0 ? '+' : ''}${provider.incomePercentageChange.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: provider.incomePercentageChange >= 0
                      ? AppColors.primaryTeal
                      : AppColors.alertRed,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 16,
                color: AppColors.textGray.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                '${provider.netForSelectedDate >= 0 ? '+' : ''}${NumberFormat('#,##0').format(provider.netForSelectedDate)}',
                style: const TextStyle(color: AppColors.textGray, fontSize: 16),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: provider.selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.primaryTeal,
                            onPrimary: AppColors.textWhite,
                            surface: AppColors.surfaceDark,
                            onSurface: AppColors.textWhite,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    provider.setSelectedDate(picked);
                  }
                },
                child: Row(
                  children: [
                    Text(
                      provider.isShowingAll
                          ? 'All Time'
                          : DateFormat('EEE, MMM d')
                              .format(provider.selectedDate),
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: AppColors.textGray),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  provider.setShowingAll();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: provider.isShowingAll
                        ? Colors.white
                            .withValues(alpha: 0.2) // Inactive when showing all
                        : AppColors.textWhite, // Active to show all
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'All',
                    style: TextStyle(
                      color: provider.isShowingAll
                          ? AppColors.textWhite.withValues(alpha: 0.5)
                          : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendersList(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final senders = provider.senders;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'View All',
                style: TextStyle(color: AppColors.textWhite, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            scrollDirection: Axis.horizontal,
            itemCount: senders.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () {
                    // Logic to add a new sender could go here
                  },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.surfaceDark,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: AppColors.textWhite,
                        size: 32,
                      ),
                    ),
                  ),
                );
              }

              final sender = senders[index - 1];

              // Today's net for this sender: income - expense for today only
              final now = DateTime.now();
              double totalNet = 0;
              final senderTx = provider.transactions.where((t) =>
                  t.name == sender.senderName &&
                  t.date.year == now.year &&
                  t.date.month == now.month &&
                  t.date.day == now.day);
              for (var tx in senderTx) {
                if (tx.type == 'income') totalNet += tx.amount;
                if (tx.type == 'expense') totalNet -= tx.amount;
              }
              final String sign = totalNet >= 0 ? '+' : '';

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
                  width: 80,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryTeal, width: 2),
                    color: AppColors.surfaceDark,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: sender.senderName.toUpperCase() == 'CBE'
                            ? Image.asset(
                                'assets/images/CBE.png',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : sender.senderName.toUpperCase() == 'TELEBIRR'
                                ? Image.asset(
                                    'assets/images/Telebirr.png',
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : sender.senderName.toUpperCase() ==
                                            'CBE BIRR' ||
                                        sender.senderName.toUpperCase() ==
                                            'CBEBIRR'
                                    ? Image.asset(
                                        'assets/images/CBEBirr.png',
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Text(
                                          sender.senderName
                                              .substring(
                                                  0,
                                                  min(3,
                                                      sender.senderName.length))
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.textGray,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                      ),
                      if (totalNet != 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: totalNet >= 0
                                  ? AppColors.primaryTeal.withValues(alpha: 0.9)
                                  : AppColors.alertRed.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$sign${NumberFormat.compact().format(totalNet.abs())}',
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
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

  Widget _buildTransactionsList(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final transactions = provider.transactionsForSelectedDate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Transactions',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const Spacer(),
              const Icon(Icons.search, color: AppColors.textGray, size: 20),
              const SizedBox(width: 16),
              const Icon(Icons.tune, color: AppColors.textGray, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshData(),
              color: AppColors.primaryTeal,
              backgroundColor: AppColors.surfaceLight,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final prevTx = index > 0 ? transactions[index - 1] : null;

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final yesterday = today.subtract(const Duration(days: 1));
                  final itemDate =
                      DateTime(tx.date.year, tx.date.month, tx.date.day);

                  bool showHeader = false;
                  if (prevTx == null) {
                    showHeader = true;
                  } else {
                    final prevDate = DateTime(
                        prevTx.date.year, prevTx.date.month, prevTx.date.day);
                    if (itemDate != prevDate) showHeader = true;
                  }

                  String dateHeader = '';
                  if (showHeader) {
                    if (itemDate == today) {
                      dateHeader = 'TODAY';
                    } else if (itemDate == yesterday) {
                      dateHeader = 'YESTERDAY';
                    } else {
                      dateHeader = DateFormat('MMM d, yyyy')
                          .format(itemDate)
                          .toUpperCase();
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 16.0, bottom: 12.0),
                          child: Text(
                            dateHeader,
                            style: const TextStyle(
                              color: AppColors.textGray,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      GestureDetector(
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
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tx.type == 'income'
                                      ? AppColors.primaryTeal
                                          .withValues(alpha: 0.1)
                                      : AppColors.textGray
                                          .withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  tx.type == 'income'
                                      ? Icons.south_west
                                      : Icons.north_east,
                                  size: 20,
                                  color: tx.type == 'income'
                                      ? AppColors.primaryTeal
                                      : AppColors.textWhite,
                                ),
                              ),
                              const SizedBox(width: 14),
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
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (index == 0) // New badge for latest
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.alertRed,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text('NEW',
                                                style: TextStyle(
                                                    color: AppColors.textWhite,
                                                    fontSize: 8,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        if (tx.reason == null) // Reason badge
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                  0xFFD97706), // Orange equivalent
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text('REASON?',
                                                style: TextStyle(
                                                    color: AppColors.textWhite,
                                                    fontSize: 8,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${tx.type == 'income' ? 'From' : 'For'} ${tx.sender}',
                                      style: const TextStyle(
                                        color: AppColors.textGray,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${tx.type == 'income' ? '+' : '-'}${NumberFormat('#,##0.0#').format(tx.amount)}',
                                    style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total ${NumberFormat('#,##0.00').format(tx.totalBalance)}',
                                    style: const TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
