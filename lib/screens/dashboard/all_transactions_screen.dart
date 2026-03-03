import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import 'transaction_detail_screen.dart';
import 'dart:math';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  String _searchQuery = '';
  String _selectedSender = 'All';
  DateTimeRange? _selectedDateRange;
  String _selectedType = 'All';
  int _searchLabelIndex = 0;
  Timer? _searchLabelTimer;

  @override
  void initState() {
    super.initState();
    _startSearchLabelRotation();
  }

  void _startSearchLabelRotation() {
    _searchLabelTimer?.cancel();
    _searchLabelTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _searchLabelIndex = (_searchLabelIndex + 1) % 3;
        });
      }
    });
  }

  String _getSearchHint(FinanceProvider provider) {
    if (_searchLabelIndex == 0) {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning ☀️';
      if (hour < 17) return 'Good Afternoon 🌤️';
      return 'Good Evening 🌙';
    } else if (_searchLabelIndex == 1) {
      return 'Search all Transactions';
    } else {
      final top = provider.topExpenseHighlight;
      if (top != null) {
        return 'HE: ${top['reason']} (${NumberFormat('#,###').format(top['amount'])} ETB)';
      }
      return 'Search all Transactions';
    }
  }

  @override
  void dispose() {
    _searchLabelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final allTransactions = provider.transactions;

    // Get unique sender names for filter
    final senderNames = ['All', ...provider.senders.map((s) => s.senderName)];

    // Filter logic
    final filteredTransactions = allTransactions.where((tx) {
      final matchesSearch =
          tx.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (tx.reason?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false) ||
              (tx.customReasonText
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false);

      final matchesSender =
          _selectedSender == 'All' || tx.name == _selectedSender;

      final matchesType = _selectedType == 'All' ||
          (_selectedType == 'Income' && tx.type == 'income') ||
          (_selectedType == 'Expense' && tx.type == 'expense');

      final matchesDate = _selectedDateRange == null ||
          (tx.date.isAfter(_selectedDateRange!.start
                  .subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1))));

      return matchesSearch && matchesSender && matchesType && matchesDate;
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F25),
        body: Column(
          children: [
            _buildHeader(context),
            _buildSearchAndFilters(context, senderNames, provider),
            Expanded(
              child: _buildTransactionList(filteredTransactions, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111315),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/images/BackForNav.svg',
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                width: 18,
                height: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'All Transactions',
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, List<String> senderNames,
      FinanceProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF111315),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textGray, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (_searchQuery.isEmpty)
                        IgnorePointer(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 600),
                            switchInCurve: Curves.easeInOutCubic,
                            switchOutCurve: Curves.easeInOutCubic,
                            layoutBuilder: (Widget? currentChild,
                                List<Widget> previousChildren) {
                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              final inAnimation = Tween<Offset>(
                                begin: const Offset(0.0, 1.2),
                                end: Offset.zero,
                              ).animate(animation);
                              final outAnimation = Tween<Offset>(
                                begin: const Offset(0.0, -1.2),
                                end: Offset.zero,
                              ).animate(animation);

                              return ClipRect(
                                child: SlideTransition(
                                  position:
                                      child.key == ValueKey(_searchLabelIndex)
                                          ? inAnimation
                                          : outAnimation,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _getSearchHint(provider),
                              key: ValueKey(_searchLabelIndex),
                              style: const TextStyle(
                                  color: AppColors.textGray, fontSize: 12),
                            ),
                          ),
                        ),
                      TextField(
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: '',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Date Filter
                _buildFilterChip(
                  label: _selectedDateRange == null
                      ? 'Date'
                      : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                  icon: Icons.calendar_today_outlined,
                  isSelected: _selectedDateRange != null,
                  onTap: _pickDateRange,
                ),
                const SizedBox(width: 8),
                // Sender Filter
                _buildFilterChip(
                  label: _selectedSender == 'All' ? 'Wallet' : _selectedSender,
                  icon: Icons.wallet_outlined,
                  isSelected: _selectedSender != 'All',
                  onTap: () => _showSenderPicker(senderNames),
                ),
                const SizedBox(width: 8),
                // Type Filter
                _buildFilterChip(
                  label: _selectedType == 'All' ? 'Type' : _selectedType,
                  icon: Icons.swap_vert_rounded,
                  isSelected: _selectedType != 'All',
                  onTap: _showTypePicker,
                ),
                if (_selectedDateRange != null ||
                    _selectedSender != 'All' ||
                    _selectedType != 'All')
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDateRange = null;
                          _selectedSender = 'All';
                          _selectedType = 'All';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.alertRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: AppColors.alertRed, size: 16),
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

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textGray,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textWhite,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textGray,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D21),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Date Range',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  // Presets
                  _buildPresetItem(
                    'All Time',
                    null,
                    setModalState,
                  ),
                  _buildPresetItem(
                    'Today',
                    DateTimeRange(
                      start: DateTime(DateTime.now().year, DateTime.now().month,
                          DateTime.now().day),
                      end: DateTime(DateTime.now().year, DateTime.now().month,
                          DateTime.now().day),
                    ),
                    setModalState,
                  ),
                  _buildPresetItem(
                    'Yesterday',
                    DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 1)),
                      end: DateTime.now().subtract(const Duration(days: 1)),
                    ),
                    setModalState,
                  ),
                  _buildPresetItem(
                    'This Month',
                    DateTimeRange(
                      start: DateTime(
                          DateTime.now().year, DateTime.now().month, 1),
                      end: DateTime.now(),
                    ),
                    setModalState,
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  // Custom Range
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        initialDateRange: _selectedDateRange,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primaryBlue,
                                onPrimary: Colors.white,
                                surface: Color(0xFF1A1D21),
                                onSurface: Colors.white,
                              ),
                              dialogTheme: DialogThemeData(
                                  backgroundColor: const Color(0xFF0A0B0D)),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedDateRange = picked);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range_rounded,
                              color: AppColors.primaryBlue),
                          const SizedBox(width: 12),
                          const Text(
                            'Custom Range...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.textGray, size: 14),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetItem(
      String title, DateTimeRange? range, StateSetter setModalState) {
    final bool isSelected = (range == null && _selectedDateRange == null) ||
        (range != null &&
            _selectedDateRange != null &&
            _selectedDateRange!.start.day == range.start.day &&
            _selectedDateRange!.end.day == range.end.day &&
            _selectedDateRange!.start.month == range.start.month);

    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primaryBlue)
          : null,
      onTap: () {
        setState(() => _selectedDateRange = range);
        Navigator.pop(context);
      },
    );
  }

  void _showSenderPicker(List<String> senderNames) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Wallet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...senderNames.map((name) => ListTile(
                    title:
                        Text(name, style: const TextStyle(color: Colors.white)),
                    trailing: _selectedSender == name
                        ? const Icon(Icons.check, color: AppColors.primaryBlue)
                        : null,
                    onTap: () {
                      setState(() => _selectedSender = name);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Transaction Type',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...['All', 'Income', 'Expense'].map((type) => ListTile(
                    title:
                        Text(type, style: const TextStyle(color: Colors.white)),
                    trailing: _selectedType == type
                        ? const Icon(Icons.check, color: AppColors.primaryBlue)
                        : null,
                    onTap: () {
                      setState(() => _selectedType = type);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionList(
      List<AppTransaction> transactions, FinanceProvider provider) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text(
              'No transactions found',
              style: TextStyle(color: AppColors.textGray, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];

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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFC7C7C7).withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _buildAvatar(tx),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.type == 'income' ? 'Deposit' : 'Transferred',
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tx.type == 'income' ? 'From' : 'For'} ${tx.sender}',
                        style: const TextStyle(
                            color: AppColors.textGray, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildAmountText(tx),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM d, HH:mm').format(tx.date),
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
    );
  }

  Widget _buildAvatar(AppTransaction tx) {
    final nameUp = tx.name.toUpperCase();
    String? assetPath;
    if (nameUp == 'CBE') {
      assetPath = 'assets/images/CBE.png';
    } else if (nameUp == 'TELEBIRR')
      assetPath = 'assets/images/Telebirr.png';
    else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR')
      assetPath = 'assets/images/CBEBirr.png';

    if (assetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(assetPath, width: 44, height: 44, fit: BoxFit.cover),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          tx.name.substring(0, min(3, tx.name.length)).toUpperCase(),
          style: const TextStyle(color: AppColors.textGray, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildAmountText(AppTransaction tx) {
    final String amountStr = NumberFormat('#,##0.00').format(tx.amount);
    final amountParts = amountStr.split('.');

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${tx.type == 'income' ? '+' : '-'}${amountParts[0]}',
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '.${amountParts[1]}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.33),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
