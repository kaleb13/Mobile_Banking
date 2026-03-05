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
        backgroundColor: const Color(0xFF1F1F25),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                decoration: InputDecoration(
                  hintText: 'Search by sender, bank, or reason...',
                  hintStyle: const TextStyle(
                      color: AppColors.labelGray,
                      fontSize: 14,
                      fontWeight: FontWeight.w400),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIconConstraints: const BoxConstraints(
                    minHeight: 24,
                    minWidth: 24,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Icon(Icons.cancel_rounded,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 18),
                          ),
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 14),
          ],
        ),
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
    final bool isDefault = value == 'All' ||
        value == 'Any Time' ||
        value == 'All Senders' ||
        value == 'All Banks';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDefault
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: isDefault ? AppColors.labelGray : Colors.white,
                size: 16),
          ),
          dropdownColor: const Color(0xFF2A2A34),
          style: TextStyle(
            color: isDefault ? AppColors.labelGray : Colors.white,
            fontSize: 12,
            fontWeight: isDefault ? FontWeight.w500 : FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth ?? 150),
                child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            );
          }).toList(),
        ),
      ),
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
