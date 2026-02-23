import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';

class TransactionDetailScreen extends StatefulWidget {
  final AppTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController =
        TextEditingController(text: widget.transaction.reason ?? '');
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isIncome = widget.transaction.type == 'income';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.primaryTeal : AppColors.alertRed;

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
          title: const Text('Transaction Detail',
              style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.normal,
                  fontSize: 18)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textWhite),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isIncome
                              ? AppColors.primaryTeal.withValues(alpha: 0.2)
                              : AppColors.alertRed.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: (isIncome
                                      ? AppColors.primaryTeal
                                      : AppColors.alertRed)
                                  .withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ]),
                      child: Icon(
                        isIncome ? Icons.south_west : Icons.north_east,
                        size: 36,
                        color: isIncome
                            ? AppColors.primaryTeal
                            : AppColors.alertRed,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$sign${NumberFormat('#,##0.0#').format(widget.transaction.amount)}',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isIncome
                            ? 'Deposit Successful'
                            : 'Transferred Successful',
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attach Reason',
                      style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reasonController,
                            style: const TextStyle(color: AppColors.textWhite),
                            decoration: InputDecoration(
                              hintText: 'e.g., Dinner, Rent, Salary...',
                              hintStyle: TextStyle(
                                  color: AppColors.textGray
                                      .withValues(alpha: 0.6)),
                              filled: true,
                              fillColor: AppColors.surfaceDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.surfaceLight
                                        .withValues(alpha: 0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.surfaceLight
                                        .withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryTeal),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Provider.of<FinanceProvider>(context, listen: false)
                                .updateTransactionReason(widget.transaction.id!,
                                    _reasonController.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reason updated'),
                                backgroundColor: AppColors.primaryTeal,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryTeal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.primaryTeal
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AppColors.surfaceLight.withValues(alpha: 0.3)),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildDetailRow('Transaction ID',
                              widget.transaction.id ?? 'Unknown'),
                          _buildDivider(),
                          _buildDetailRow(
                              'Category', widget.transaction.category),
                          _buildDivider(),
                          _buildDetailRow(
                              'Sender / Recipient', widget.transaction.sender),
                          _buildDivider(),
                          _buildDetailRow(
                              'Date',
                              DateFormat('dd MMM yyyy, HH:mm')
                                  .format(widget.transaction.date)),
                          _buildDivider(),
                          _buildDetailRow('Total Balance',
                              '${NumberFormat('#,##0.00').format(widget.transaction.totalBalance)} ETB'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Information Source Raw Message',
                      style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AppColors.surfaceLight.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        widget.transaction.rawMessage,
                        style: TextStyle(
                            color: AppColors.textGray.withValues(alpha: 0.7),
                            height: 1.6,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textGray, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
        color: AppColors.surfaceLight.withValues(alpha: 0.3), height: 1);
  }
}
