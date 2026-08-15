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
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
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
              backgroundColor: context.themeBackground,
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

    // Hide when resting on Home (t <= 0.02) or resting on/beyond Wallet Page (t >= 0.98 || provider.pageOffset >= 0.98)
    if (t <= 0.02 || t >= 0.98 || provider.pageOffset >= 0.98) return const SizedBox.shrink();

    final senders = provider.senders;
    if (senders.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;
    final overdueOffset = provider.overdueLoans.isNotEmpty ? 44.0 : 0.0;
    final topScrollOffset = provider.homeTopScrollOffset.clamp(0.0, double.infinity);
    final deckTop = topPadding + 68.0 + overdueOffset - topScrollOffset;

    // Dynamic ordered card list: active bank senders + Cash Wallet + paused bank senders
    final orderedNames = provider.orderedWalletNames;
    final int totalCards = orderedNames.length;
    final int activeCount = provider.activeSenders.length;
    final bool hasPaused = provider.pausedSenders.isNotEmpty;

    // Home deck (t=0.0) left-offset pattern matching DashboardScreen
    const double baseLeftOffset = -42.0;
    const double leftStep = 22.0;

    final List<Widget> cardWidgets = [];

    for (int i = 0; i < totalCards; i++) {
      final String cardName = orderedNames[i];
      final bool isCashWallet = cardName == 'Cash Wallet';
      final bool isPaused =
          isCashWallet ? false : provider.isTrackingPaused(cardName);
      // Only the first 3 active bank senders are visible on the Home page deck
      final bool isVisibleOnHome = !isPaused && !isCashWallet && i < 3;

      // ── Wallet list position (t=1.0) ──────────────────────────────
      const double walletLeft = 16.0;
      final double headerOffset = (hasPaused && i > activeCount) ? 36.0 : 0.0;
      final double walletTop = topPadding + 62.0 + i * 174.0 + headerOffset;
      final double walletW = screenWidth - 32.0;
      const double walletH = 160.0;

      // ── Home deck position (t=0.0) ────────────────────────────────
      // Visible-on-Home cards get their own stacked offset; all others
      // collapse behind the last visible deck card.
      final int deckIndex =
          isVisibleOnHome ? i : 2.clamp(0, activeCount > 0 ? activeCount - 1 : 0);
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
      // Top 3 active bank senders: always visible during flight
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
      final double balance = provider.balanceForSender(cardName);
      final int txCount = provider.txCountForSender(cardName);

      final Widget card = BankCardWidget(
        senderName: cardName,
        balance: balance,
        txCount: txCount,
        isBalanceVisible: provider.isBalanceVisible,
        isPaused: isPaused,
        animationFactor: t,
      );

      cardWidgets.add(
        Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: Opacity(
            opacity: cardOpacity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (t <= 0.05) {
                  provider.animateToTab(1);
                }
              },
              child: card,
            ),
          ),
        ),
      );
    }

    final bool shouldIgnorePointer = t > 0.01;

    return IgnorePointer(
      ignoring: shouldIgnorePointer,
      child: Stack(
        clipBehavior: Clip.none,
        children: cardWidgets,
      ),
    );
  }
}
