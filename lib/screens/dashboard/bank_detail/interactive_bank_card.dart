import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/sender.dart';
import '../../../models/bank_account_item.dart';
import '../../../presentation/viewmodels/settings_view_model.dart';
import '../../../presentation/viewmodels/transactions_view_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bank_card_widget.dart';
import '../../../widgets/currency_symbol_widget.dart';
import '../../../widgets/interactive_drag_handle.dart';
import 'bank_behind_info_panel.dart';
import 'bank_metadata.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Stacked Sliding Bank Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class InteractiveBankCard extends StatefulWidget {
  final AppSender sender;
  final double topSafeArea;
  final double collapseRatio;
  final double contentOpacity;
  final double grabLinesOpacity;
  final double currentCornerRadius;
  final double currentBalance;
  final double monthChange;
  final double monthPercent;
  final int txCount;
  final bool isChartVisible;
  final List<BankAccountItem> accounts;
  final int selectedAccountIndex;
  final ValueChanged<int>? onAccountChanged;
  final ValueChanged<int>? onToggleAccountPause;
  final VoidCallback onAddTransaction;
  final VoidCallback onAnalytics;
  final VoidCallback onShowPnlInfo;
  final VoidCallback onCredentials;
  final VoidCallback onToggleChart;

  const InteractiveBankCard({
    super.key,
    required this.sender,
    required this.topSafeArea,
    required this.collapseRatio,
    required this.contentOpacity,
    required this.grabLinesOpacity,
    required this.currentCornerRadius,
    required this.currentBalance,
    required this.monthChange,
    required this.monthPercent,
    required this.txCount,
    required this.isChartVisible,
    this.accounts = const [],
    this.selectedAccountIndex = 0,
    this.onAccountChanged,
    this.onToggleAccountPause,
    required this.onAddTransaction,
    required this.onAnalytics,
    required this.onShowPnlInfo,
    required this.onCredentials,
    required this.onToggleChart,
  });

  @override
  State<InteractiveBankCard> createState() => _InteractiveBankCardState();
}

class _InteractiveBankCardState extends State<InteractiveBankCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _dragOffset = 0.0;
  static const double _maxSlideDown = 184.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didUpdateWidget(covariant InteractiveBankCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {});
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.collapseRatio > 0.1) return;
    setState(() {
      _dragOffset =
          (_dragOffset + details.primaryDelta!).clamp(0.0, _maxSlideDown);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset > 0.0) {
      _animCtrl.value = _dragOffset / _maxSlideDown;
      setState(() => _dragOffset = 0.0);
      _animCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _togglePeek() {
    if (widget.collapseRatio > 0.1) return;
    if (_animCtrl.isAnimating) return;

    // Quick subtle bounce (~5-6% slide down) to act as a clue that the card can be dragged
    _animCtrl
        .animateTo(
          0.06,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
      if (mounted) {
        _animCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final txVM = context.watch<TransactionsViewModel>();
    final settingsVM = context.watch<SettingsViewModel>();
    final fmt = NumberFormat('#,##0.00');
    final senderName = widget.sender.senderName;

    // Check if this bank is the top card (white version) in the active bank deck:
    final activeSenders = txVM.activeSenders;
    final int topDeckIndex = activeSenders.isNotEmpty
        ? (activeSenders.length.clamp(1, 3) - 1)
        : -1;
    final int senderIndex = activeSenders.indexWhere(
        (s) => s.senderName.toUpperCase() == senderName.toUpperCase());
    final bool isTopCard =
        (senderIndex >= 0 && senderIndex == topDeckIndex);

    final cardColors =
        BankCardWidget.getCardGradient(senderName, isTopCard: isTopCard);
    final infoData = BankInfoData.forBank(senderName);
    final bool isDarkTextTheme =
        BankCardWidget.isDarkTextTheme(senderName, isTopCard: isTopCard);

    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        final double animatedSlide = _animCtrl.value * _maxSlideDown;
        final double currentSlide =
            (_dragOffset + animatedSlide).clamp(0.0, _maxSlideDown);
        final double revealProgress =
            (currentSlide / _maxSlideDown).clamp(0.0, 1.0);
        final double topCornerRadius =
            (currentSlide / 20.0).clamp(0.0, 1.0) * 24.0;

        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // ── Stacked Revealed Behind Info Card ──
              BankBehindInfoPanel(
                topSafeArea: widget.topSafeArea,
                currentSlide: currentSlide,
                revealProgress: revealProgress,
                infoData: infoData,
              ),

              // ── Front Sliding Bank Card ──
              Transform.translate(
                offset: Offset(0, currentSlide),
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Background Card Shape & Drop Shadow
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: cardColors,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(topCornerRadius),
                            topRight: Radius.circular(topCornerRadius),
                            bottomLeft:
                                Radius.circular(widget.currentCornerRadius),
                            bottomRight:
                                Radius.circular(widget.currentCornerRadius),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Bar (Back button, and fading-in Bank Logo + Title on scroll)
                    Positioned(
                      top: widget.topSafeArea,
                      left: 16,
                      right: 16,
                      height: 54,
                      child: Row(
                        children: [
                          AppBackButton(
                            variant: isDarkTextTheme
                                ? AppBackButtonVariant.dark
                                : AppBackButtonVariant.auto,
                          ),
                          Opacity(
                            opacity:
                                (widget.collapseRatio * 2.0).clamp(0.0, 1.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                BankCardWidget.bankLogo(
                                  senderName,
                                  20,
                                  null,
                                  isDarkTextTheme,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  infoData.displayName,
                                  style: TextStyle(
                                    color: textColorPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body Content (Logo/Header Row, Balance, PNL Chip, Action Buttons)
                    if (widget.contentOpacity > 0.0)
                      Positioned(
                        top: widget.topSafeArea +
                            54.0 -
                            (widget.collapseRatio * 20.0),
                        left: 18,
                        right: 18,
                        child: Opacity(
                          opacity: widget.contentOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bank Identity & Eye Toggle Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  BankCardWidget.bankLogo(
                                    senderName,
                                    34,
                                    null,
                                    isDarkTextTheme,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          infoData.subtitle,
                                          style: TextStyle(
                                            color: textColorSub,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${widget.txCount} Transactions',
                                          style: TextStyle(
                                            color: textColorSub,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Refresh / Rescan Button
                                  IconButton(
                                    icon: Icon(
                                      Icons.refresh_rounded,
                                      color: textColorSub,
                                      size: 19,
                                    ),
                                    splashRadius: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: widget.onCredentials,
                                  ),
                                ],
                              ),
                              if (widget.accounts.length > 1) ...[
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: List.generate(widget.accounts.length, (idx) {
                                      final acct = widget.accounts[idx];
                                      final isSelected = idx == widget.selectedAccountIndex;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: GestureDetector(
                                          onTap: () => widget.onAccountChanged?.call(idx),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (isDarkTextTheme
                                                      ? AppColors.darkCharcoal
                                                      : Colors.white)
                                                  : (isDarkTextTheme
                                                      ? AppColors.darkCharcoal
                                                          .withValues(alpha: 0.14)
                                                      : Colors.white
                                                          .withValues(alpha: 0.20)),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  acct.simSlot == null
                                                      ? Icons.account_balance_wallet_outlined
                                                      : Icons.sim_card_outlined,
                                                  size: 11,
                                                  color: isSelected
                                                      ? (isDarkTextTheme
                                                          ? Colors.white
                                                          : AppColors.darkCharcoal)
                                                      : textColorPrimary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  acct.label,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? (isDarkTextTheme
                                                            ? Colors.white
                                                            : AppColors.darkCharcoal)
                                                        : textColorPrimary,
                                                  ),
                                                ),
                                                if (acct.isPaused) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    width: 5,
                                                    height: 5,
                                                    decoration: const BoxDecoration(
                                                      color: AppColors.negative,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),

                              // Balance & 30D PNL Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: settingsVM.isBalanceVisible
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  (widget.txCount == 0 && widget.currentBalance == 0.0)
                                                      ? 'Unknown Balance'
                                                      : fmt.format(widget.currentBalance),
                                                  style: TextStyle(
                                                    color: textColorPrimary,
                                                    fontSize: (widget.txCount == 0 && widget.currentBalance == 0.0)
                                                        ? 22
                                                        : 28,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.5,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                                if (widget.txCount > 0 || widget.currentBalance > 0.0) ...[
                                                  const SizedBox(width: 6),
                                                  CurrencySymbolWidget(
                                                    color: textColorPrimary,
                                                    size: 19,
                                                  ),
                                                ],
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.visibility_outlined,
                                                    color: textColorSub,
                                                    size: 18,
                                                  ),
                                                  splashRadius: 18,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () => settingsVM
                                                      .toggleBalanceVisibility(),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '••••••••',
                                                  style: TextStyle(
                                                    color: textColorPrimary,
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.5,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.visibility_off_outlined,
                                                    color: textColorSub,
                                                    size: 18,
                                                  ),
                                                  splashRadius: 18,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () => settingsVM
                                                      .toggleBalanceVisibility(),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _build30DPnlChip(
                                    change: widget.monthChange,
                                    percent: widget.monthPercent,
                                    textColor: textColorPrimary,
                                    isDarkTheme: isDarkTextTheme,
                                    onTap: widget.onShowPnlInfo,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 100% Fully Rounded Action Pill Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton.primary(
                                      text: 'Add Tx',
                                      icon: Icons.add_rounded,
                                      height: 40,
                                      fontSize: 12,
                                      iconSize: 15,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      onLightSurface: isDarkTextTheme,
                                      onPressed: widget.onAddTransaction,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AppButton.secondary(
                                      text: 'Analytics',
                                      icon: Icons.insights_rounded,
                                      height: 40,
                                      fontSize: 12,
                                      iconSize: 15,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      onLightSurface: isDarkTextTheme,
                                      onPressed: widget.onAnalytics,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AppButton.secondary(
                                      text: widget.isChartVisible
                                          ? 'Hide Chart'
                                          : 'Show Chart',
                                      icon: widget.isChartVisible
                                          ? Icons.bar_chart_rounded
                                          : Icons.show_chart_rounded,
                                      height: 40,
                                      fontSize: 12,
                                      iconSize: 15,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      onLightSurface: isDarkTextTheme,
                                      onPressed: widget.onToggleChart,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Interactive Single Drag Handle Area (Tappable & Draggable)
                    if (widget.grabLinesOpacity > 0.0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 30,
                        child: Opacity(
                          opacity: widget.grabLinesOpacity,
                          child: Center(
                            child: InteractiveDragHandle(
                              color: isDarkTextTheme
                                  ? AppColors.darkCharcoal
                                      .withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.35),
                              width: 36,
                              height: 4,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              onTap: _togglePeek,
                              onVerticalDragUpdate: _onDragUpdate,
                              onVerticalDragEnd: _onDragEnd,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _build30DPnlChip({
    required double change,
    required double percent,
    required Color textColor,
    required bool isDarkTheme,
    required VoidCallback onTap,
  }) {
    if (widget.txCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDarkTheme
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'No activity yet',
          style: TextStyle(
            color: textColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final isPositive = change >= 0;
    final fmt = NumberFormat('#,##0.00');
    final formattedChange =
        '${isPositive ? '+' : ''}${fmt.format(change)}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDarkTheme
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 11,
              color: isPositive ? AppColors.positive : AppColors.negative,
            ),
            const SizedBox(width: 3),
            Text(
              formattedChange,
              style: TextStyle(
                color: textColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.info_outline_rounded,
              size: 10,
              color: textColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
