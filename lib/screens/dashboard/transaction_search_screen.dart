import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import 'transaction_detail_screen.dart';
import 'dart:math';

class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  State<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final allTransactions = provider.transactions;

    final filteredTransactions = allTransactions.where((tx) {
      if (_searchQuery.isEmpty) return false;
      final searchLower = _searchQuery.toLowerCase();
      final nameStr = tx.name.toLowerCase();
      final senderStr = tx.sender.toLowerCase();
      final reasonStr = tx.reason?.toLowerCase() ?? '';
      final customReasonStr = tx.customReasonText?.toLowerCase() ?? '';
      final amountStr = tx.amount.toString();
      final rawStr = tx.rawMessage.toLowerCase();

      return nameStr.contains(searchLower) ||
          senderStr.contains(searchLower) ||
          reasonStr.contains(searchLower) ||
          customReasonStr.contains(searchLower) ||
          amountStr.contains(searchLower) ||
          rawStr.contains(searchLower);
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F25),
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchHeader(context),
              Expanded(
                child: _searchQuery.isEmpty
                    ? _buildInitialState()
                    : _buildSearchResults(filteredTransactions, provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A34),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search_rounded,
                      color: AppColors.labelGray, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search by sender, bank, or reason...',
                        hintStyle: TextStyle(
                            color: AppColors.labelGray,
                            fontSize: 14,
                            fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.cancel_rounded,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 18),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded,
              size: 64, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Search by name, amount, or reason',
            style:
                TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
      List<AppTransaction> transactions, FinanceProvider provider) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 16),
            const Text(
              'No transactions found',
              style: TextStyle(color: AppColors.labelGray, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final bool isIncome = tx.type == 'income';
        final String amountStr = NumberFormat('#,##0.0').format(tx.amount);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(transaction: tx)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A34).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildAvatar(tx),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncome ? 'Deposit' : 'Transferred',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${isIncome ? 'From' : 'For'} ${tx.sender}',
                        style: const TextStyle(
                            color: AppColors.labelGray, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}$amountStr',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, HH:mm').format(tx.date),
                      style: const TextStyle(
                          color: AppColors.labelGray, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(AppTransaction tx) {
    final nameUp = tx.name.toUpperCase();
    Widget? img;
    if (nameUp == 'CBE') {
      img = Image.asset('assets/images/CBE logo 1.png', width: 22, height: 22);
    } else if (nameUp == 'TELEBIRR') {
      img =
          Image.asset('assets/images/Telebirr Logo.png', width: 22, height: 22);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img =
          Image.asset('assets/images/CBEBirr Logo.png', width: 22, height: 22);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: img ??
            Text(
              tx.name.substring(0, min(1, tx.name.length)).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
      ),
    );
  }
}
