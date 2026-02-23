import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/sender.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'transaction_detail_screen.dart';

class SenderDetailScreen extends StatelessWidget {
  final AppSender sender;

  const SenderDetailScreen({super.key, required this.sender});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final transactions = provider.transactions
        .where((tx) => tx.name == sender.senderName)
        .toList();

    double currentBalance = 0;
    double totalDeposit = 0;
    double totalTransfer = 0;
    double totalCash = 0;

    if (transactions.isNotEmpty) {
      currentBalance = transactions.first.totalBalance;
    }

    for (var tx in transactions) {
      if (tx.category.toLowerCase() == 'deposit') {
        totalDeposit += tx.amount;
      } else if (tx.category.toLowerCase() == 'transfer') {
        totalTransfer += tx.amount;
      } else if (tx.category.toLowerCase() == 'cash') {
        totalCash += tx.amount;
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('${sender.senderName} Details',
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.normal,
                  fontSize: 18)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textWhite),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 100, bottom: 40),
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, 0.5),
                  radius: 1.2,
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
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceLight.withValues(alpha: 0.3),
                      border:
                          Border.all(color: AppColors.primaryTeal, width: 2),
                    ),
                    child: sender.senderName.toUpperCase() == 'CBE'
                        ? ClipOval(
                            child: Image.asset(
                              'assets/images/CBE.png',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        : sender.senderName.toUpperCase() == 'TELEBIRR'
                            ? ClipOval(
                                child: Image.asset(
                                  'assets/images/Telebirr.png',
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : sender.senderName.toUpperCase() == 'CBE BIRR' ||
                                    sender.senderName.toUpperCase() == 'CBEBIRR'
                                ? ClipOval(
                                    child: Image.asset(
                                      'assets/images/CBEBirr.png',
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      sender.senderName.length >= 3
                                          ? sender.senderName
                                              .substring(0, 3)
                                              .toUpperCase()
                                          : sender.senderName.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Total Balance',
                    style: TextStyle(color: AppColors.textGray, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat('#,##0.00').format(currentBalance),
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildStatColumn('Deposit', totalDeposit,
                            Icons.download, AppColors.primaryTeal),
                      ),
                      Expanded(
                        child: _buildStatColumn('Transfer', totalTransfer,
                            Icons.upload, AppColors.textWhite),
                      ),
                      Expanded(
                        child: _buildStatColumn('Cash', totalCash, Icons.money,
                            AppColors.textWhite),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.refreshData(),
                color: AppColors.primaryTeal,
                backgroundColor: AppColors.surfaceLight,
                child: transactions.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: Text('No transactions yet.',
                                style: TextStyle(color: AppColors.textGray)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 8.0),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final prevTx =
                              index > 0 ? transactions[index - 1] : null;

                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final yesterday =
                              today.subtract(const Duration(days: 1));
                          final itemDate = DateTime(
                              tx.date.year, tx.date.month, tx.date.day);

                          bool showHeader = false;
                          if (prevTx == null) {
                            showHeader = true;
                          } else {
                            final prevDate = DateTime(prevTx.date.year,
                                prevTx.date.month, prevTx.date.day);
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
                                  padding: const EdgeInsets.only(
                                      top: 16.0, bottom: 12.0),
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
                                          TransactionDetailScreen(
                                              transaction: tx),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                if (index ==
                                                    0) // New badge for latest
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 8),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.alertRed,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Text('NEW',
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .textWhite,
                                                            fontSize: 8,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                if (tx.reason ==
                                                    null) // Reason badge
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFD97706), // Orange equivalent
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Text('REASON?',
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .textWhite,
                                                            fontSize: 8,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                            DateFormat('MMM d, HH:mm')
                                                .format(tx.date),
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
      ),
    );
  }

  Widget _buildStatColumn(
      String label, double amount, IconData icon, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.textGray, fontSize: 13),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            NumberFormat('#,##0.00').format(amount),
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
