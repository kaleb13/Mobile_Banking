import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'manual_transaction_sheet.dart';
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
  double? _touchedX;

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
              child: Column(
                children: [
                  _buildSearchHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildBankCard(
                              currentBalance, monthChange, monthPercent),
                          const SizedBox(height: 24),
                          _buildChartSection(allTxForSender),
                          _buildChartFilters(),
                          const SizedBox(height: 32),
                          _buildActivityFilterSection(),
                          _buildTransactionList(filteredTransactions),
                          const SizedBox(height: 110), // clears the bottom bar
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Search Input
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A34),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search_rounded,
                      color: AppColors.labelGray, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search in ${widget.sender.senderName}...',
                        hintStyle: const TextStyle(
                          color: AppColors.labelGray,
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        suffixIconConstraints:
                            const BoxConstraints(minHeight: 24, minWidth: 24),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      size: 16),
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
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCard(double balance, double change, double percent) {
    final nameUp = widget.sender.senderName.toUpperCase();
    String subTitle = '';
    String imagePath = 'assets/images/CBE logo 1.png';

    if (nameUp.contains('CBE')) {
      subTitle = 'Bank';
    }
    if (nameUp.contains('TELEBIRR')) {
      subTitle = 'E-money';
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp.contains('CBEBIRR') || nameUp.contains('CBE BIRR')) {
      subTitle = 'Wallet';
      imagePath = 'assets/images/CBEBirr Logo.png';
    }

    List<Color> cardGradient;
    if (nameUp == 'CBE') {
      cardGradient = [
        const Color(0xFF3D1B0F),
        const Color(0xFF6E482F),
        const Color(0xFF3D1B0F)
      ];
    } else if (nameUp.contains('TELEBIRR')) {
      cardGradient = [
        const Color(0xFF0BA751),
        const Color(0xFF88BF47),
        const Color(0xFF0BA751)
      ];
    } else if (nameUp.contains('CBEBIRR') || nameUp.contains('CBE BIRR')) {
      cardGradient = [
        const Color(0xFFAFAFB3),
        const Color(0xFFFFFFFF),
        const Color(0xFFAFAFB3)
      ];
    } else {
      cardGradient = [
        const Color(0xFF1E1E26),
        const Color(0xFF3E3E4A),
        const Color(0xFF1E1E26)
      ];
    }

    final textColor =
        (nameUp.contains('CBEBIRR') || nameUp.contains('CBE BIRR'))
            ? Colors.black
            : Colors.white;
    final isPositive = change >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: cardGradient.first.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(29),
                gradient: RadialGradient(
                  center: Alignment.centerRight,
                  radius: 1.5,
                  colors: cardGradient,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: Stack(
                  children: [
                    // Right aligned huge logo/image
                    Positioned(
                      right: -10,
                      top: 10,
                      bottom: 0,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        width: 140,
                      ),
                    ),
                    // Content padding
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.sender.senderName,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.5,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subTitle.isNotEmpty)
                                Text(
                                  subTitle,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your balance',
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Consumer<FinanceProvider>(
                                builder: (context, provider, child) {
                                  return GestureDetector(
                                    onTap: provider.toggleBalanceVisibility,
                                    behavior: HitTestBehavior.opaque,
                                    child: Text(
                                      provider.isBalanceVisible
                                          ? NumberFormat('#,##0.00')
                                              .format(balance)
                                          : '****.**',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                        height: 1.1,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '30D PNL  ',
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.7),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '${isPositive ? '+' : '-'}${NumberFormat('#,##0').format(change.abs())}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    isPositive
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color: textColor,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${percent.abs().toStringAsFixed(2)}%)',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F25),
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

              // ── CENTER: Plus Button for Manual Transaction ───────────────────
              Positioned(
                left: circleW + gap,
                top: 0,
                width: pillWidth,
                height: 56,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ManualTransactionSheet(
                        provider: provider,
                        initialSender: widget.sender,
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFF301900),
                          size: 28,
                        ),
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

    // Gradient configuration
    List<double> lineStops = [0.0, 1.0];
    List<Color> lineColors = [AppColors.accentBlue, AppColors.accentBlue];

    List<Color> fillColors = [
      AppColors.accentBlue.withValues(alpha: 0.28),
      AppColors.accentBlue.withValues(alpha: 0.0),
    ];

    if (_touchedX != null && spots.isNotEmpty) {
      final maxX = spots.last.x;
      if (maxX > 0) {
        double ratio = (_touchedX! / maxX).clamp(0.0, 1.0);
        lineStops = [0.0, ratio, ratio, 1.0];
        lineColors = [
          AppColors.accentBlue,
          AppColors.accentBlue,
          AppColors.accentBlue.withValues(alpha: 0.08),
          AppColors.accentBlue.withValues(alpha: 0.08),
        ];
        fillColors = [
          AppColors.accentBlue.withValues(alpha: 0.07),
          AppColors.accentBlue.withValues(alpha: 0.0),
        ];
      }
    }

    return Container(
      height: 120, // Match Dashboard height
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchCallback:
                (FlTouchEvent event, LineTouchResponse? touchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    touchResponse == null ||
                    touchResponse.lineBarSpots == null ||
                    touchResponse.lineBarSpots!.isEmpty) {
                  _touchedX = null;
                  return;
                }
                _touchedX = touchResponse.lineBarSpots!.first.x;
              });
            },
            getTouchedSpotIndicator:
                (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: Colors.white.withValues(alpha: 0.2),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.accentBlue,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  return LineTooltipItem(
                    '',
                    const TextStyle(),
                    children: [
                      TextSpan(
                        text: 'ETB ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: NumberFormat('#,##0').format(s.y),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(
                colors: lineColors,
                stops: lineStops,
              ),
              barWidth: 1.8,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: fillColors,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
}
