import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_dropdown.dart';
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
  String _typeFilter = 'All';
  String _dateFilter = 'Any Time';
  String _senderFilter = 'All Senders';
  String _bankFilter = 'All Banks';

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
    final allSenders = ['All Senders'];
    allSenders
        .addAll(allTransactions.map((t) => t.sender).toSet().toList()..sort());

    if (!allSenders.contains(_senderFilter)) {
      _senderFilter = 'All Senders';
    }

    final allBanks = ['All Banks'];
    allBanks
        .addAll(allTransactions.map((t) => t.name).toSet().toList()..sort());

    if (!allBanks.contains(_bankFilter)) {
      _bankFilter = 'All Banks';
    }

    final filteredTransactions = allTransactions.where((tx) {
      if (_typeFilter == 'Incoming' && tx.type != 'income') return false;
      if (_typeFilter == 'Outgoing' && tx.type != 'expense') return false;

      if (_senderFilter != 'All Senders' && tx.sender != _senderFilter) {
        return false;
      }

      if (_bankFilter != 'All Banks' && tx.name != _bankFilter) {
        return false;
      }

      if (_dateFilter != 'Any Time') {
        final now = DateTime.now();
        final txDate = tx.date;
        if (_dateFilter == 'Today') {
          if (txDate.year != now.year ||
              txDate.month != now.month ||
              txDate.day != now.day) {
            return false;
          }
        } else if (_dateFilter == 'This Week') {
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfToday =
              DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          if (txDate.isBefore(startOfToday)) return false;
        } else if (_dateFilter == 'This Month') {
          if (txDate.year != now.year || txDate.month != now.month) {
            return false;
          }
        }
      }

      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final nameStr = tx.name.toLowerCase();
        final senderStr = tx.sender.toLowerCase();
        final reasonStr = tx.reason?.toLowerCase() ?? '';
        final customReasonStr = tx.customReasonText?.toLowerCase() ?? '';
        final amountStr = tx.amount.toString();
        final rawStr = tx.rawMessage.toLowerCase();

        final matchesSearch = nameStr.contains(searchLower) ||
            senderStr.contains(searchLower) ||
            reasonStr.contains(searchLower) ||
            customReasonStr.contains(searchLower) ||
            amountStr.contains(searchLower) ||
            rawStr.contains(searchLower);

        return matchesSearch;
      }
      return true;
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchHeader(context),
              _buildFilterRow(allSenders, allBanks),
              Expanded(
                child: _searchQuery.isEmpty &&
                        _typeFilter == 'All' &&
                        _dateFilter == 'Any Time' &&
                        _senderFilter == 'All Senders' &&
                        _bankFilter == 'All Banks'
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: AppSearchBar(
        mode: AppSearchBarMode.bar,
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        hint: 'Search by sender, bank, or reason...',
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        onClear: () {
          setState(() {
            _searchQuery = '';
          });
        },
        trailing: GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        backgroundColor: AppColors.surfaceElevated,
        textColor: Colors.white,
        hintColor: AppColors.textSoft,
        iconColor: AppColors.textSoft,
        height: 46,
        borderRadius: 23,
      ),
    );
  }

  Widget _buildFilterRow(List<String> senders, List<String> banks) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildFilterDropdown(
              value: _typeFilter,
              items: const ['All', 'Incoming', 'Outgoing'],
              onChanged: (val) {
                if (val != null) setState(() => _typeFilter = val);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterDropdown(
              value: _dateFilter,
              items: const ['Any Time', 'Today', 'This Week', 'This Month'],
              onChanged: (val) {
                if (val != null) setState(() => _dateFilter = val);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterDropdown(
              value: _bankFilter,
              items: banks,
              maxWidth: 90,
              onChanged: (val) {
                if (val != null) setState(() => _bankFilter = val);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterDropdown(
              value: _senderFilter,
              items: senders,
              maxWidth: 100,
              onChanged: (val) {
                if (val != null) setState(() => _senderFilter = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double? maxWidth,
  }) {
    return AppDropdown.simple(
      value: value,
      items: items,
      onChanged: onChanged,
      variant: AppDropdownVariant.dark,
      maxWidth: maxWidth,
      icon: Icons.unfold_more_rounded,
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded,
              size: 64, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          Text(
            'Search by name, amount, or reason',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
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
                size: 64, color: Colors.white.withValues(alpha: 0.05)),
            const SizedBox(height: 16),
            const Text(
              'No transactions found',
              style: TextStyle(color: AppColors.textSoft, fontSize: 14),
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
              color: AppColors.surface,
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
                            color: AppColors.textSoft, fontSize: 11),
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
                      provider.isBalanceVisible
                          ? '${isIncome ? '+' : '-'}$amountStr'
                          : '****',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, HH:mm').format(tx.date),
                      style: const TextStyle(
                          color: AppColors.textSoft, fontSize: 10),
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
      img = Image.asset('assets/images/CBE logo 1.webp', width: 22, height: 22);
    } else if (nameUp == 'TELEBIRR') {
      img =
          Image.asset('assets/images/Telebirr Logo.png', width: 22, height: 22);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img =
          Image.asset('assets/images/CBEBirr Logo.png', width: 22, height: 22);
    } else if (nameUp.contains('AHADU')) {
      img =
          SvgPicture.asset('assets/images/Ahadu_Logo.svg', width: 22, height: 22, fit: BoxFit.contain);
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      img =
          SvgPicture.asset('assets/images/Bank_of_Abyssinia_Icon.svg', width: 22, height: 22, fit: BoxFit.contain);
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
