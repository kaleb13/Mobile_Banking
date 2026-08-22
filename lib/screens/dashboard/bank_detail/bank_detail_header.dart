import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../../models/sender.dart';

import 'interactive_bank_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic Telegram-Style Collapsing Header Delegate for Bank Detail Pages
// ─────────────────────────────────────────────────────────────────────────────
class BankDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AppSender sender;

  final double topSafeArea;
  final double currentBalance;
  final double monthChange;
  final double monthPercent;
  final int txCount;
  final bool isChartVisible;
  final VoidCallback onAddTransaction;
  final VoidCallback onAnalytics;
  final VoidCallback onShowPnlInfo;
  final VoidCallback onCredentials;
  final VoidCallback onToggleChart;

  BankDetailHeaderDelegate({
    required this.sender,

    required this.topSafeArea,
    required this.currentBalance,
    required this.monthChange,
    required this.monthPercent,
    required this.txCount,
    required this.isChartVisible,
    required this.onAddTransaction,
    required this.onAnalytics,
    required this.onShowPnlInfo,
    required this.onCredentials,
    required this.onToggleChart,
  });

  @override
  double get minExtent => topSafeArea + 58.0;

  @override
  double get maxExtent => topSafeArea + 238.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double collapseRatio =
        ((shrinkOffset) / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final double contentOpacity =
        (1.0 - collapseRatio * 2.2).clamp(0.0, 1.0);
    final double grabLinesOpacity =
        (1.0 - collapseRatio * 3.0).clamp(0.0, 1.0);
    final double currentCornerRadius =
        lerpDouble(28.0, 0.0, collapseRatio)!;

    return InteractiveBankCard(
      sender: sender,
      topSafeArea: topSafeArea,
      collapseRatio: collapseRatio,
      contentOpacity: contentOpacity,
      grabLinesOpacity: grabLinesOpacity,
      currentCornerRadius: currentCornerRadius,
      currentBalance: currentBalance,
      monthChange: monthChange,
      monthPercent: monthPercent,
      txCount: txCount,
      isChartVisible: isChartVisible,
      onAddTransaction: onAddTransaction,
      onAnalytics: onAnalytics,
      onShowPnlInfo: onShowPnlInfo,
      onCredentials: onCredentials,
      onToggleChart: onToggleChart,
    );
  }

  @override
  bool shouldRebuild(covariant BankDetailHeaderDelegate oldDelegate) => true;
}
