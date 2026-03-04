import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/sender.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'transaction_detail_screen.dart';

class SenderDetailScreen extends StatefulWidget {
  final AppSender sender;

  const SenderDetailScreen({super.key, required this.sender});

  @override
  State<SenderDetailScreen> createState() => _SenderDetailScreenState();
}

class _SenderDetailScreenState extends State<SenderDetailScreen> {
  String _chartFilter = '30D'; // 1D, 7D, 30D, 180D, 360D
  String _searchQuery = '';
  String _typeFilter = 'All'; // All, Income, Expense
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final allTxForSender = provider.transactions
        .where((tx) => tx.name == widget.sender.senderName)
        .toList();

    // Chart date filter
    DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
    if (_chartFilter == '1D') {
      cutoff = DateTime.now().subtract(const Duration(days: 1));
    } else if (_chartFilter == '7D') {
      cutoff = DateTime.now().subtract(const Duration(days: 7));
    } else if (_chartFilter == '30D') {
      cutoff = DateTime.now().subtract(const Duration(days: 30));
    } else if (_chartFilter == '180D') {
      cutoff = DateTime.now().subtract(const Duration(days: 180));
    } else if (_chartFilter == '360D') {
      cutoff = DateTime.now().subtract(const Duration(days: 360));
    }

    // Filter transactions for listing & chart
    final filteredTransactions = allTxForSender.where((tx) {
      final matchesDate = tx.date.isAfter(cutoff);
      final matchesSearch =
          tx.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (tx.resolvedReason
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false);
      final matchesType = _typeFilter == 'All' ||
          (_typeFilter == 'Income' && tx.type == 'income') ||
          (_typeFilter == 'Expense' && tx.type != 'income');
      return matchesDate && matchesSearch && matchesType;
    }).toList();

    // Calculate Balance & Trends
    double currentBalance =
        allTxForSender.isNotEmpty ? allTxForSender.first.totalBalance : 0;

    // Trend calculation
    double monthChange = 0;
    double monthPercent = 0;
    if (allTxForSender.isNotEmpty) {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final thisMonthTx =
          allTxForSender.where((tx) => tx.date.isAfter(thirtyDaysAgo)).toList();
      for (var tx in thisMonthTx) {
        if (tx.type == 'income') {
          monthChange += tx.amount;
        } else {
          monthChange -= tx.amount;
        }
      }
      if (currentBalance != 0) {
        monthPercent =
            (monthChange / (currentBalance - monthChange).abs()) * 100;
        if (monthPercent.isInfinite || monthPercent.isNaN) monthPercent = 0;
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
        backgroundColor: const Color(0xFF1F1F25),
        extendBody: true,
        extendBodyBehindAppBar: true,
        // ── Floating bottom pill nav bar ──
        bottomNavigationBar: _buildBottomNav(context, provider),
        body: Stack(
          children: [
            // Background Gradient
            _buildBackground(),

            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildBalanceSection(
                        currentBalance, monthChange, monthPercent),
                    _buildChartSection(allTxForSender),
                    _buildChartFilters(),
                    const SizedBox(height: 32),
                    _buildActivityFilterSection(),
                    _buildTransactionList(filteredTransactions),
                    // Extra space so last item clears the bottom bar
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1F1F25),
            Color(0xFF1B1B21),
          ],
        ),
      ),
    );
  }

  /// Variant bottom nav — same sizing/geometry as the home CustomBottomNavBar,
  /// with bank-specific content (refresh | logo+name pill | back).
  Widget _buildBottomNav(BuildContext context, FinanceProvider provider) {
    return Container(
      // Identical margins to CustomBottomNavBar
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          // Two 56-wide circles + the pill fills the rest
          const circleW = 56.0;
          const gap = 8.0;
          final pillWidth = totalWidth - (circleW * 2) - (gap * 2);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // ── LEFT: Refresh circle ──────────────────────────────────
              Positioned(
                left: 0,
                top: 0,
                width: circleW,
                height: 56,
                child: GestureDetector(
                  onTap: () => provider.refreshData(),
                  behavior: HitTestBehavior.opaque,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF2A2A34).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── CENTER: Bank logo + name pill ─────────────────────────
              Positioned(
                left: circleW + gap,
                top: 0,
                width: pillWidth,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A34).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Bank logo — same compact circle
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _getSenderLogo(size: 11),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            widget.sender.senderName.toLowerCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── RIGHT: Back circle ────────────────────────────────────
              Positioned(
                left: totalWidth - circleW,
                top: 0,
                width: circleW,
                height: 56,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF2A2A34).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/images/BackForNav.svg',
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceSection(double balance, double change, double percent) {
    final isPositive = change >= 0;
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Column(
        children: [
          Text(
            'Net Account Value',
            style: TextStyle(
              color: AppColors.labelGray,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<FinanceProvider>(
            builder: (context, provider, child) {
              final formatter = NumberFormat('#,##0.00');
              final String fullyFormatted = provider.isBalanceVisible
                  ? formatter.format(balance)
                  : '****.**';
              final parts = fullyFormatted.split('.');

              return GestureDetector(
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
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '.${parts[1]}',
                      style: TextStyle(
                        color: AppColors.labelGray,
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? AppColors.mintGreen : AppColors.alertRed,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${isPositive ? '+' : ''}${NumberFormat('#,##0.00').format(change)} (${percent.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: isPositive ? AppColors.mintGreen : AppColors.alertRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Profit & Loss',
                style: TextStyle(
                  color: AppColors.labelGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Net balance change over the last 30 days',
            style: TextStyle(
              color: AppColors.labelGray,
              fontSize: 10,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(List<AppTransaction> transactions) {
    if (transactions.isEmpty) return const SizedBox(height: 100);

    // Filter data based on selection
    DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
    if (_chartFilter == '1D') {
      cutoff = DateTime.now().subtract(const Duration(days: 1));
    } else if (_chartFilter == '7D') {
      cutoff = DateTime.now().subtract(const Duration(days: 7));
    } else if (_chartFilter == '30D') {
      cutoff = DateTime.now().subtract(const Duration(days: 30));
    } else if (_chartFilter == '180D') {
      cutoff = DateTime.now().subtract(const Duration(days: 180));
    } else if (_chartFilter == '360D') {
      cutoff = DateTime.now().subtract(const Duration(days: 360));
    }

    final filtered = transactions
        .where((tx) => tx.date.isAfter(cutoff))
        .toList()
        .reversed
        .toList();
    if (filtered.isEmpty) return const SizedBox(height: 100);

    final spots = filtered.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalBalance);
    }).toList();

    return Container(
      height: 100, // Further decreased height
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceLight,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  return LineTooltipItem(
                    'ETB ${NumberFormat('#,##0').format(s.y)}',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.accentBlue,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accentBlue.withValues(alpha: 0.15),
                    AppColors.accentBlue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ['1D', '7D', '30D', '180D', '360D'].map((f) {
          final isSelected = _chartFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _chartFilter = f),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.transparent),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.labelGray,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: TextStyle(color: AppColors.labelGray),
                icon: Icon(Icons.search, color: AppColors.labelGray, size: 20),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Type Filter Chips
          Row(
            children: ['All', 'Income', 'Expense'].map((t) {
              final isSelected = _typeFilter == t;
              return GestureDetector(
                onTap: () => setState(() => _typeFilter = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.labelGray,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'ACTIVITY',
            style: TextStyle(
              color: AppColors.labelGray,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<AppTransaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('No matching transactions.',
              style: TextStyle(color: AppColors.labelGray)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _buildTransactionItem(tx);
      },
    );
  }

  Widget _buildTransactionItem(AppTransaction tx) {
    final isIncome = tx.type == 'income';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: tx)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isIncome
                    ? AppColors.mintGreen.withValues(alpha: 0.10)
                    : AppColors.alertRed.withValues(alpha: 0.10),
              ),
              child: Icon(
                isIncome ? Icons.south_west : Icons.north_east,
                size: 18,
                color: isIncome ? AppColors.mintGreen : AppColors.alertRed,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.resolvedReason ?? (isIncome ? 'Deposit' : 'Expense'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(tx.date),
                    style: const TextStyle(
                        color: AppColors.labelGray, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${NumberFormat('#,##0.0').format(tx.amount)}',
                  style: TextStyle(
                    color: isIncome ? AppColors.mintGreen : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ETB',
                  style:
                      const TextStyle(color: AppColors.labelGray, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getSenderLogo({double size = 20}) {
    final name = widget.sender.senderName.toUpperCase();
    if (name == 'CBE') {
      return ClipOval(
          child: Image.asset('assets/images/CBE.png', fit: BoxFit.cover));
    } else if (name == 'TELEBIRR') {
      return ClipOval(
          child: Image.asset('assets/images/Telebirr.png', fit: BoxFit.cover));
    } else if (name == 'CBE BIRR' || name == 'CBEBIRR') {
      return ClipOval(
          child: Image.asset('assets/images/CBEBirr.png', fit: BoxFit.cover));
    }
    return Center(
      child: Text(
        name.length >= 3 ? name.substring(0, 3) : name,
        style: TextStyle(
          color: AppColors.textWhite,
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
