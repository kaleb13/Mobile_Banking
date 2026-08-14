import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import 'transaction_detail_screen.dart';
import 'dart:math';

class AllTransactionsScreen extends StatefulWidget {
  final String? initialSearchQuery;

  const AllTransactionsScreen({super.key, this.initialSearchQuery});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedSender = 'All';
  DateTimeRange? _selectedDateRange;
  String _selectedType = 'All';
  int _searchLabelIndex = 0;
  Timer? _searchLabelTimer;
  bool _isSenderMenuOpen = false;
  bool _isTypeMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _searchController = TextEditingController(text: _searchQuery);
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
    _searchController.dispose();
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
      bool matchesSearch = false;
      if (_searchQuery.toLowerCase() == 'uncategorized') {
        matchesSearch = tx.resolvedReason == null || tx.resolvedReason!.isEmpty;
      } else if (_searchQuery.isEmpty) {
        matchesSearch = true;
      } else {
        final query = _searchQuery.toLowerCase();
        matchesSearch =
            tx.sender.toLowerCase().contains(query) ||
            (tx.reason?.toLowerCase().contains(query) ?? false) ||
            (tx.customReasonText?.toLowerCase().contains(query) ?? false) ||
            (tx.resolvedReason?.toLowerCase().contains(query) ?? false);
      }

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

    final double totalSum = filteredTransactions.fold<double>(0, (s, t) => s + t.amount);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildTopHeaderAndSearch(context, senderNames, provider, totalSum, filteredTransactions.length),
            Expanded(
              child: _buildTransactionList(filteredTransactions, provider),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seamless Top Header & Search/Filter Section ────────────────────────────
  Widget _buildTopHeaderAndSearch(
    BuildContext context,
    List<String> senderNames,
    FinanceProvider provider,
    double totalSum,
    int count,
  ) {
    final bool isReasonFilter = widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty;

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 12,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Clean Back Arrow + Title + Clear Button
          Row(
            children: [
              const AppBackButton(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReasonFilter ? widget.initialSearchQuery! : 'Transactions',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isReasonFilter ? 'Reason Analysis Detail' : '$count transactions recorded',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (_searchQuery.isNotEmpty || _selectedSender != 'All' || _selectedType != 'All' || _selectedDateRange != null)
                AppButton.destructive(
                  text: 'Clear',
                  fullWidth: false,
                  height: 28,
                  fontSize: 11,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedSender = 'All';
                      _selectedType = 'All';
                      _selectedDateRange = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Fully Rounded Search Bar (No border) ──────────────────────────
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (_searchQuery.isEmpty)
                        IgnorePointer(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              _getSearchHint(provider),
                              key: ValueKey(_searchLabelIndex),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: '',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
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
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.buttonSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Selection Filter Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildDateFilterChip(),
                const SizedBox(width: 8),
                _buildSenderDropdown(senderNames),
                const SizedBox(width: 8),
                _buildTypeDropdown(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip() {
    final bool isSelected = _selectedDateRange != null;
    final String dateText = _selectedDateRange == null
        ? 'Date'
        : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}';

    return AppButton.pill(
      text: dateText,
      icon: Icons.calendar_today_rounded,
      trailingIcon: Icons.keyboard_arrow_down_rounded,
      isSelected: isSelected,
      onPressed: _pickDateRange,
    );
  }

  Widget _buildSenderDropdown(List<String> senderNames) {
    final bool isSelected = _selectedSender != 'All';
    final bool isActive = isSelected || _isSenderMenuOpen;
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.12),
      ),
      child: PopupMenuButton<String>(
        onOpened: () => setState(() => _isSenderMenuOpen = true),
        onCanceled: () => setState(() => _isSenderMenuOpen = false),
        offset: const Offset(0, 38),
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
        borderRadius: BorderRadius.circular(100),
        padding: EdgeInsets.zero,
        color: AppColors.surface,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onSelected: (name) => setState(() {
          _isSenderMenuOpen = false;
          _selectedSender = name;
        }),
        itemBuilder: (context) => senderNames.map((name) {
          final isItemSel = _selectedSender == name;
          return PopupMenuItem<String>(
            value: name,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isItemSel ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          isItemSel ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isItemSel)
                  const Icon(Icons.check_rounded,
                      color: AppColors.positive, size: 16),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : AppColors.buttonSecondary,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 14,
                color: isActive
                    ? AppColors.buttonPrimaryText
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  _selectedSender == 'All' ? 'Wallet' : _selectedSender,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.buttonPrimaryText
                        : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: isActive
                    ? AppColors.buttonPrimaryText
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    final bool isSelected = _selectedType != 'All';
    final bool isActive = isSelected || _isTypeMenuOpen;
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.12),
      ),
      child: PopupMenuButton<String>(
        onOpened: () => setState(() => _isTypeMenuOpen = true),
        onCanceled: () => setState(() => _isTypeMenuOpen = false),
        offset: const Offset(0, 38),
        constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
        borderRadius: BorderRadius.circular(100),
        padding: EdgeInsets.zero,
        color: AppColors.surface,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onSelected: (type) => setState(() {
          _isTypeMenuOpen = false;
          _selectedType = type;
        }),
        itemBuilder: (context) => ['All', 'Income', 'Expense'].map((type) {
          final isItemSel = _selectedType == type;
          return PopupMenuItem<String>(
            value: type,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isItemSel ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          isItemSel ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (isItemSel)
                  const Icon(Icons.check_rounded,
                      color: AppColors.positive, size: 16),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : AppColors.buttonSecondary,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 14,
                color: isActive
                    ? AppColors.buttonPrimaryText
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                _selectedType == 'All' ? 'Type' : _selectedType,
                style: TextStyle(
                  color: isActive
                      ? AppColors.buttonPrimaryText
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: isActive
                    ? AppColors.buttonPrimaryText
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgMid,
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
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
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
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
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
                                primary: AppColors.gold,
                                onPrimary: AppColors.textPrimary,
                                surface: AppColors.bgMid,
                                onSurface: AppColors.textPrimary,
                              ),
                              dialogTheme: const DialogThemeData(
                                  backgroundColor: AppColors.bgDeep),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        if (!context.mounted) return;
                        setState(() => _selectedDateRange = picked);
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.date_range_rounded,
                              color: AppColors.gold),
                          SizedBox(width: 12),
                          Text(
                            'Custom Range...',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.textSecondary, size: 14),
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
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.gold)
          : null,
      onTap: () {
        setState(() => _selectedDateRange = range);
        Navigator.pop(context);
      },
    );
  }

  // ── Cardless Transaction List ──────────────────────────────────────────────
  Widget _buildTransactionList(
      List<AppTransaction> transactions, FinanceProvider provider) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No transactions found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.white.withValues(alpha: 0.06),
      ),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _buildTransactionRowItem(context, tx, provider);
      },
    );
  }

  Widget _buildTransactionRowItem(
      BuildContext context, AppTransaction tx, FinanceProvider provider) {
    final bool isIncome = tx.type == 'income';
    final String label = isIncome ? 'Deposit' : 'Transferred';
    final String subLabel = isIncome ? 'From ${tx.sender}' : 'For ${tx.sender}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: tx),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildDarkBankAvatar(tx.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tx.reasonId == null &&
                            (tx.customReasonText == null ||
                                tx.customReasonText!.isEmpty) &&
                            (tx.reason == null || tx.reason!.isEmpty))
                          const Padding(
                            padding: EdgeInsets.only(left: 6.0),
                            child: ReasonBadge(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAmountText(tx, provider),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, HH:mm').format(tx.date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkBankAvatar(String bankName) {
    final nameUp = bankName.toUpperCase();
    Widget img;
    Color bgColor = AppColors.buttonSecondary;

    if (nameUp == 'CBE') {
      img = Image.asset('assets/images/CBE logo 1.webp',
          width: 20, height: 20, fit: BoxFit.contain);
      bgColor = const Color(0xFF6B4C9A).withValues(alpha: 0.20);
    } else if (nameUp == 'TELEBIRR') {
      img = Image.asset('assets/images/Telebirr Logo.png',
          width: 20, height: 20, fit: BoxFit.contain);
      bgColor = AppColors.telebirrGreen.withValues(alpha: 0.20);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = Image.asset('assets/images/CBEBirr Logo.png',
          width: 20, height: 20, fit: BoxFit.contain);
      bgColor = const Color(0xFFE91E63).withValues(alpha: 0.20);
    } else if (nameUp.contains('AHADU')) {
      img = Image.asset('assets/images/Ahadu_Logo.png',
          width: 20, height: 20, fit: BoxFit.contain);
      bgColor = const Color(0xFFFF9800).withValues(alpha: 0.20);
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      img = SvgPicture.asset('assets/images/Bank_of_Abyssinia_Icon.svg',
          width: 20, height: 20, fit: BoxFit.contain);
      bgColor = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else {
      img = Text(
        bankName.substring(0, min(1, bankName.length)).toUpperCase(),
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(child: img),
    );
  }

  Widget _buildAmountText(AppTransaction tx, FinanceProvider provider) {
    if (!provider.isBalanceVisible) {
      return const Text(
        '****',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final String amountStr = NumberFormat('#,##0.00').format(tx.amount);
    final amountParts = amountStr.split('.');

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${tx.type == 'income' ? '+' : '-'}${amountParts[0]}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '.${amountParts[1]}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
