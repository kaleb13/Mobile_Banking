import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../../presentation/viewmodels/settings_view_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bank_card_widget.dart';
import '../../../widgets/currency_symbol_widget.dart';
import '../../../widgets/interactive_drag_handle.dart';
import '../bank_detail/bank_behind_info_panel.dart';
import '../bank_detail/bank_metadata.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic Telegram-Style Collapsing Header Delegate
// ─────────────────────────────────────────────────────────────────────────────
class CashWalletHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onAddCash;
  final VoidCallback onDeduct;
  final VoidCallback onTemplates;
  final double topSafeArea;

  CashWalletHeaderDelegate({
    required this.onAddCash,
    required this.onDeduct,
    required this.onTemplates,
    required this.topSafeArea,
  });

  @override
  double get minExtent => topSafeArea + 58.0;

  @override
  double get maxExtent => topSafeArea + 242.0;

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

    return InteractiveCashWalletCard(
      topSafeArea: topSafeArea,
      collapseRatio: collapseRatio,
      contentOpacity: contentOpacity,
      grabLinesOpacity: grabLinesOpacity,
      currentCornerRadius: currentCornerRadius,
      onAddCash: onAddCash,
      onDeduct: onDeduct,
      onTemplates: onTemplates,
    );
  }

  @override
  bool shouldRebuild(covariant CashWalletHeaderDelegate oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Stacked Sliding Cash Wallet Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class InteractiveCashWalletCard extends StatefulWidget {
  final double topSafeArea;
  final double collapseRatio;
  final double contentOpacity;
  final double grabLinesOpacity;
  final double currentCornerRadius;
  final VoidCallback onAddCash;
  final VoidCallback onDeduct;
  final VoidCallback onTemplates;

  const InteractiveCashWalletCard({
    super.key,
    required this.topSafeArea,
    required this.collapseRatio,
    required this.contentOpacity,
    required this.grabLinesOpacity,
    required this.currentCornerRadius,
    required this.onAddCash,
    required this.onDeduct,
    required this.onTemplates,
  });

  @override
  State<InteractiveCashWalletCard> createState() =>
      _InteractiveCashWalletCardState();
}

class _InteractiveCashWalletCardState extends State<InteractiveCashWalletCard>
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
  void didUpdateWidget(covariant InteractiveCashWalletCard oldWidget) {
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
    final cashVM = context.watch<CashWalletViewModel>();
    final settingsVM = context.watch<SettingsViewModel>();
    final fmt = NumberFormat('#,##0.00');
    final cardColors = BankCardWidget.getCardGradient('Cash Wallet');

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
              // ── Stacked Revealed Top Info Card (Full Width behind front card) ──
              BankBehindInfoPanel(
                topSafeArea: widget.topSafeArea,
                currentSlide: currentSlide,
                revealProgress: revealProgress,
                infoData: BankInfoData.forBank('Cash Wallet'),
              ),

              // ── Front Sliding Cash Wallet Card ──
              Transform.translate(
                offset: Offset(0, currentSlide),
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Background Card Shape & Ambient Drop Shadow (Matches exact Wallet Manager Card Gradient)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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

                    // Top Bar (Back button, and fading-in Logo + Title on scroll)
                    Positioned(
                      top: widget.topSafeArea,
                      left: 16,
                      right: 16,
                      height: 54,
                      child: Row(
                        children: [
                          const AppBackButton(),
                          Opacity(
                            opacity:
                                (widget.collapseRatio * 2.0).clamp(0.0, 1.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                const AppSvgIcon(
                                  'assets/images/Wallet Icon.svg',
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Cash Wallet',
                                  style: TextStyle(
                                    color: Colors.white,
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

                    // Body Content (Available Cash, Big Balance, Action Buttons)
                    if (widget.contentOpacity > 0.0)
                      Positioned(
                        top: widget.topSafeArea +
                            54.0 -
                            (widget.collapseRatio * 20.0),
                        left: 16,
                        right: 16,
                        child: Opacity(
                          opacity: widget.contentOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'AVAILABLE CASH',
                                style: TextStyle(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: settingsVM.isBalanceVisible
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            fmt.format(cashVM.cashBalance),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 34,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                          ),
                                          const SizedBox(width: 6),
                                          const CurrencySymbolWidget(
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: Icon(
                                              Icons.visibility_outlined,
                                              color: Colors.white
                                                  .withValues(alpha: 0.8),
                                              size: 20,
                                            ),
                                            splashRadius: 20,
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
                                          const Text(
                                            '••••••••',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 34,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: Icon(
                                              Icons.visibility_off_outlined,
                                              color: Colors.white
                                                  .withValues(alpha: 0.8),
                                              size: 20,
                                            ),
                                            splashRadius: 20,
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                            onPressed: () => settingsVM
                                                .toggleBalanceVisibility(),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton.primary(
                                      text: 'Add Cash',
                                      icon: Icons.add_rounded,
                                      height: 44,
                                      fontSize: 12.5,
                                      iconSize: 16,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      onPressed: widget.onAddCash,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AppButton.secondary(
                                      text: 'Deduct',
                                      icon: Icons.remove_rounded,
                                      height: 44,
                                      fontSize: 12.5,
                                      iconSize: 16,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      onPressed: widget.onDeduct,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AppButton.secondary(
                                      text: 'Templates',
                                      icon: Icons.receipt_long_rounded,
                                      height: 44,
                                      fontSize: 12.5,
                                      iconSize: 15,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      onPressed: widget.onTemplates,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Interactive Single Drag Handle Area (Tappable & Draggable like Home Transaction Section)
                    if (widget.grabLinesOpacity > 0.0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 32,
                        child: Opacity(
                          opacity: widget.grabLinesOpacity,
                          child: Center(
                            child: InteractiveDragHandle(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 36,
                              height: 4,
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
}
