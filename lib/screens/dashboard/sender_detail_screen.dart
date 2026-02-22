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
    if (transactions.isNotEmpty) {
      currentBalance = transactions.first.totalBalance;
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
                            : Center(
                                child: Text(
                                  sender.senderName
                                      .substring(0, 3)
                                      .toUpperCase(),
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
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions yet.',
                          style: TextStyle(color: AppColors.textGray)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
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
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
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
                                        ? Icons.call_received
                                        : Icons.call_made,
                                    color: tx.type == 'income'
                                        ? AppColors.primaryTeal
                                        : AppColors.textWhite,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.type == 'income'
                                            ? 'Deposit'
                                            : 'Withdraw',
                                        style: const TextStyle(
                                          color: AppColors.textWhite,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${tx.type == 'income' ? 'From' : 'For'} ${tx.sender}',
                                        style: const TextStyle(
                                          color: AppColors.textGray,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${tx.type == 'income' ? '+' : '-'}${NumberFormat('#,##0.0').format(tx.amount)}',
                                      style: const TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM d, HH:mm')
                                          .format(tx.date),
                                      style: const TextStyle(
                                        color: AppColors.textGray,
                                        fontSize: 10,
                                      ),
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
      ),
    );
  }
}
