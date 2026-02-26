import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _chartFilter = '1M'; // 1W, 1M, ALL
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

    // Filter transactions for listing
    final filteredTransactions = allTxForSender.where((tx) {
      final matchesSearch =
          tx.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (tx.resolvedReason
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false);
      final matchesType = _typeFilter == 'All' ||
          (_typeFilter == 'Income' && tx.type == 'income') ||
          (_typeFilter == 'Expense' && tx.type != 'income');
      return matchesSearch && matchesType;
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
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0B0D),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Background Gradient (Trading app style)
            _buildBackground(),

            SafeArea(
              child: Column(
                children: [
                  _buildTopNav(context, provider),
                  Expanded(
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
                          const SizedBox(height: 40),
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.0),
          radius: 1.2,
          colors: [
            AppColors.accentBlue,
            AppColors.primaryBlue,
            Color(0xFF0A0B0D),
          ],
          stops: [0.0, 0.3, 0.8],
        ),
      ),
    );
  }

  Widget _buildTopNav(BuildContext context, FinanceProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavIconButton(
            Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(context),
          ),
          Row(
            children: [
              Hero(
                tag: 'sender_logo_${widget.sender.senderName}',
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: _getSenderLogo(size: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.sender.senderName.toLowerCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          _buildNavIconButton(
            Icons.refresh,
            onTap: () => provider.refreshData(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
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
              color: Colors.white.withValues(alpha: 0.6),
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
                        color: Colors.white.withValues(alpha: 0.33),
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
                  color: Colors.white.withValues(alpha: 0.4),
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
              color: Colors.white.withValues(alpha: 0.25),
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
    if (_chartFilter == '1W') {
      cutoff = DateTime.now().subtract(const Duration(days: 7));
    } else if (_chartFilter == 'ALL') {
      cutoff = DateTime(2000);
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

    // Peak marker logic
    double maxY = 0;
    int peakIndex = 0;
    for (int i = 0; i < spots.length; i++) {
      if (spots[i].y > maxY) {
        maxY = spots[i].y;
        peakIndex = i;
      }
    }

    return Container(
      height: 100, // Further decreased height
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent
          ],
          stops: [0.0, 0.15, 0.85, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
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
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    if (index == peakIndex) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AppColors.accentBlue,
                      );
                    }
                    return FlDotCirclePainter(
                        radius: 0, color: Colors.transparent);
                  },
                ),
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
      ),
    );
  }

  Widget _buildChartFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ['1W', '1M', 'ALL'].map((f) {
          final isSelected = _chartFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _chartFilter = f),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentBlue.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isSelected ? AppColors.accentBlue : Colors.white10),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isSelected ? AppColors.accentBlue : AppColors.textGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: TextStyle(color: AppColors.textGray),
                icon: Icon(Icons.search, color: AppColors.textGray, size: 20),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Type Filter Chips
          Row(
            children: ['All', 'Income', 'Expense'].map((t) {
              final isSelected = _typeFilter == t;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(t),
                  selected: isSelected,
                  onSelected: (v) => setState(() => _typeFilter = t),
                  backgroundColor: Colors.transparent,
                  selectedColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textGray,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : Colors.white12),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'ACTIVITY',
            style: TextStyle(
              color: AppColors.textGray,
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
              style: TextStyle(color: AppColors.textGray)),
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
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isIncome
                    ? AppColors.mintGreen.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                isIncome ? Icons.south_west : Icons.north_east,
                size: 18,
                color: isIncome ? AppColors.mintGreen : AppColors.textGray,
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
                        color: AppColors.textGray, fontSize: 11),
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
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
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
