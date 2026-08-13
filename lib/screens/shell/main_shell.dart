import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/analysis_screen.dart';
import '../dashboard/profile_hub_screen.dart';
import '../wallets/wallets_screen.dart';
import '../loans/loan_management_screen.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bank_card_widget.dart';
import 'custom_bottom_nav_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  DateTime? _lastBackPressTime;
  late final PageController _pageController;

  // Page order: Home | Wallet | Analysis | Loans | Settings
  static const _pageCount = 5; // nav-visible pages

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<FinanceProvider>();
        provider.tabNavigationNotifier.addListener(_onTabNavigationRequested);
      }
    });
  }

  void _onPageScroll() {
    if (mounted && _pageController.hasClients) {
      final offset = _pageController.page ?? 0.0;
      context.read<FinanceProvider>().setPageOffset(offset);
    }
  }

  void _onTabNavigationRequested() {
    if (!mounted || !_pageController.hasClients) return;
    final provider = context.read<FinanceProvider>();
    final targetIndex = provider.tabNavigationNotifier.value;
    if (targetIndex != null) {
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index, FinanceProvider provider) {
    if (index == provider.currentScreenIndex) return;
    provider.setScreenIndex(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index, FinanceProvider provider) {
    if (mounted && index < _pageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          provider.setScreenIndex(index);
        }
      });
    }
  }

  Future<bool> _onWillPop(FinanceProvider provider) async {
    final currentIndex = provider.currentScreenIndex;

    if (currentIndex != 0) {
      provider.setScreenIndex(0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      return false;
    }

    final now = DateTime.now();
    final isFirstPress = _lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2);

    if (isFirstPress) {
      _lastBackPressTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Press back again to exit',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: AppColors.overlay,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
          final currentIndex = provider.currentScreenIndex;

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final shouldExit = await _onWillPop(provider);
              if (shouldExit && context.mounted) {
                SystemNavigator.pop();
              }
            },
            child: Scaffold(
              backgroundColor: AppColors.background,
              extendBody: true,
              // PageView gives us free horizontal swipe + clean slide transition
              body: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (index) => _onPageChanged(index, provider),
                    children: const [
                      // Order: Home | Wallet | Analysis | Loans | Profile Hub
                      DashboardScreen(),
                      WalletsScreen(),
                      AnalysisScreen(),
                      LoanManagementScreen(),
                      ProfileHubScreen(),
                    ],
                  ),
                  _buildFlyingCardsOverlay(context, provider),
                ],
              ),
              bottomNavigationBar: (provider.isMenuOpen || isKeyboardOpen)
                  ? const SizedBox.shrink()
                  : CustomBottomNavBar(
                      currentIndex: currentIndex,
                      pageController: _pageController,
                      onTap: (index) => _onNavTap(index, provider),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlyingCardsOverlay(BuildContext context, FinanceProvider provider) {
    final t = provider.pageOffset.clamp(0.0, 1.0);
    final isWalletTab = provider.currentScreenIndex == 1;
    final isRestingOnWallet = isWalletTab && (t >= 0.95);

    // Hide when resting on Home (t <= 0.05) or fully/resting on Wallet Page (isRestingOnWallet || t >= 0.98)
    // On Wallet Manager, real in-tree cards render 100% fully expanded.
    if (t <= 0.05 || isRestingOnWallet || t >= 0.98) return const SizedBox.shrink();

    final senders = provider.senders;
    if (senders.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;
    final overdueOffset = provider.overdueLoans.isNotEmpty ? 44.0 : 0.0;
    final topScrollOffset = provider.homeTopScrollOffset.clamp(0.0, double.infinity);
    final deckTop = topPadding + 68.0 + overdueOffset - topScrollOffset;

    // Unified card list: all bank senders + Cash Wallet (always last)
    final int totalCards = senders.length + 1;

    // Home deck (t=0.0) left-offset pattern matching DashboardScreen
    const double baseLeftOffset = -42.0;
    const double leftStep = 22.0;

    // Pre-compute Cash Wallet tx count (same logic as wallets_screen)
    int cashTxCount = 0;
    for (var tx in provider.transactions) {
      if (tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash') {
        cashTxCount++;
      }
    }
    cashTxCount += provider.cashTransactions.length;

    final List<Widget> cardWidgets = [];

    for (int i = 0; i < totalCards; i++) {
      final bool isCashWallet = i == senders.length;
      final String cardName =
          isCashWallet ? 'Cash Wallet' : senders[i].senderName;
      // Only the first 3 bank senders are visible on the Home page deck
      final bool isVisibleOnHome = !isCashWallet && i < 3;

      // ── Wallet list position (t=1.0) ──────────────────────────────
      const double walletLeft = 16.0;
      final double walletTop = topPadding + 62.0 + i * 174.0;
      final double walletW = screenWidth - 32.0;
      const double walletH = 160.0;

      // ── Home deck position (t=0.0) ────────────────────────────────
      // Visible-on-Home cards get their own stacked offset; all others
      // collapse behind the last visible deck card.
      final int deckIndex =
          isVisibleOnHome ? i : 2.clamp(0, senders.length - 1);
      final double deckLeftOffset = baseLeftOffset + deckIndex * leftStep;
      final double homeLeft = screenWidth - 105.0 + deckLeftOffset + 42.0;
      const double homeW = 100.0;
      const double homeH = 185.0;

      // Interpolate position
      final double left = lerpDouble(homeLeft, walletLeft, t)!;
      final double top = lerpDouble(deckTop, walletTop, t)!;
      final double w = lerpDouble(homeW, walletW, t)!;
      final double h = lerpDouble(homeH, walletH, t)!;

      // ── Opacity ───────────────────────────────────────────────────
      // Top 3 bank senders: always visible during flight
      // Others: smoothly fade in from t ≈ 0.15 → 0.60, invisible on Home
      final double cardOpacity;
      if (isVisibleOnHome) {
        cardOpacity = 1.0;
      } else {
        cardOpacity = ((t - 0.15) / 0.45).clamp(0.0, 1.0);
      }

      // Skip rendering fully invisible cards
      if (cardOpacity < 0.001) continue;

      // ── Build card widget ─────────────────────────────────────────
      final Widget card;
      if (isCashWallet) {
        card = BankCardWidget(
          senderName: 'Cash Wallet',
          balance: provider.cashBalance,
          txCount: cashTxCount,
          isBalanceVisible: provider.isBalanceVisible,
          isPaused: false,
          animationFactor: t,
        );
      } else {
        final senderTxs = provider.transactions
            .where((tx) =>
                tx.name.trim().toUpperCase() == cardName.trim().toUpperCase())
            .toList();

        double balance = 0;
        final withBal = senderTxs.where((tx) => tx.totalBalance > 0);
        if (withBal.isNotEmpty) {
          balance = withBal.first.totalBalance;
        }

        final isPaused = provider.isTrackingPaused(cardName);

        card = BankCardWidget(
          senderName: cardName,
          balance: balance,
          txCount: senderTxs.length,
          isBalanceVisible: provider.isBalanceVisible,
          isPaused: isPaused,
          animationFactor: t,
        );
      }

      cardWidgets.add(
        Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: Opacity(
            opacity: cardOpacity,
            child: GestureDetector(
              onTap: () {
                if (t <= 0.05) provider.setScreenIndex(1);
              },
              child: card,
            ),
          ),
        ),
      );
    }

    final bool shouldIgnorePointer = t > 0.01;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topHeaderY = topPadding + 56.0 + overdueOffset;
    final double maxBottomY = provider.homeSheetTopY ?? screenHeight;

    return IgnorePointer(
      ignoring: shouldIgnorePointer,
      child: ClipRect(
        clipper: _FlyingCardsClipper(
          topHeaderY: topHeaderY,
          maxBottomY: maxBottomY,
          t: t,
        ),
        child: Stack(
          children: cardWidgets,
        ),
      ),
    );
  }
}

class _FlyingCardsClipper extends CustomClipper<Rect> {
  final double topHeaderY;
  final double maxBottomY;
  final double t;

  _FlyingCardsClipper({
    required this.topHeaderY,
    required this.maxBottomY,
    required this.t,
  });

  @override
  Rect getClip(Size size) {
    // Top boundary: On Home (t=0.0), clip any pixels above topHeaderY so cards NEVER overlap Section 1A (Notification Header).
    // Bottom boundary: On Home (t=0.0), clip any pixels below maxBottomY (top edge of White Transaction Section).
    // As t approaches 1.0 (swiping to Wallet page), smoothly remove clipping to allow full flight.
    final double effectiveTop = topHeaderY * (1.0 - t);
    final double effectiveBottom = size.height * t + maxBottomY * (1.0 - t);
    return Rect.fromLTRB(0, effectiveTop, size.width, effectiveBottom);
  }

  @override
  bool shouldReclip(_FlyingCardsClipper oldClipper) {
    return oldClipper.topHeaderY != topHeaderY ||
        oldClipper.maxBottomY != maxBottomY ||
        oldClipper.t != t;
  }
}
