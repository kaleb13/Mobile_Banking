import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/analysis_screen.dart';
import '../dashboard/profile_hub_screen.dart';
import '../wallets/wallets_screen.dart';
import '../loans/loan_management_screen.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/loans_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/app_toast.dart';
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
        final settingsVM = context.read<SettingsViewModel>();
        settingsVM.tabNavigationNotifier.addListener(_onTabNavigationRequested);
      }
    });
  }

  void _onPageScroll() {
    if (mounted && _pageController.hasClients) {
      final offset = _pageController.page ?? 0.0;
      context.read<SettingsViewModel>().setPageOffset(offset);
    }
  }

  void _navigateToTab(int toIndex, SettingsViewModel settingsVM) {
    if (!mounted || !_pageController.hasClients) return;
    final fromIndex = settingsVM.currentScreenIndex;
    if (toIndex == fromIndex) return;

    final diff = (toIndex - fromIndex).abs();

    if (diff == 1) {
      // Adjacent navigation (e.g. Home <-> Wallet): smooth slide with flying cards
      settingsVM.setScreenIndex(toIndex);
      _pageController.animateToPage(
        toIndex,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Non-adjacent navigation (e.g. Home -> Loans, Wallet -> Profile):
      // Direct jump without rendering or scrolling through middle pages
      settingsVM.setScreenIndex(toIndex);
      _pageController.jumpToPage(toIndex);
      settingsVM.setPageOffset(toIndex.toDouble());
    }
  }

  void _onTabNavigationRequested() {
    if (!mounted || !_pageController.hasClients) return;
    final settingsVM = context.read<SettingsViewModel>();
    final targetIndex = settingsVM.tabNavigationNotifier.value;
    if (targetIndex != null) {
      _navigateToTab(targetIndex, settingsVM);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index, SettingsViewModel settingsVM) {
    _navigateToTab(index, settingsVM);
  }

  void _onPageChanged(int index, SettingsViewModel settingsVM) {
    if (mounted && index < _pageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          settingsVM.setScreenIndex(index);
        }
      });
    }
  }

  Future<bool> _onWillPop(SettingsViewModel settingsVM) async {
    final currentIndex = settingsVM.currentScreenIndex;

    if (currentIndex != 0) {
      _navigateToTab(0, settingsVM);
      return false;
    }

    final now = DateTime.now();
    final isFirstPress = _lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2);

    if (isFirstPress) {
      _lastBackPressTime = now;
      if (mounted) {
        AppToast.info(context, message: 'Press back again to exit');
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
      child: Selector<SettingsViewModel, ({int currentIndex, bool isMenuOpen})>(
        selector: (_, vm) => (
          currentIndex: vm.currentScreenIndex,
          isMenuOpen: vm.isMenuOpen,
        ),
        builder: (context, navData, child) {
          final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
          final currentIndex = navData.currentIndex;
          final settingsVM = Provider.of<SettingsViewModel>(context, listen: false);

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final shouldExit = await _onWillPop(settingsVM);
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
                    onPageChanged: (index) => _onPageChanged(index, settingsVM),
                    children: const [
                      // Order: Home | Wallet | Analysis | Loans | Profile Hub
                      DashboardScreen(),
                      WalletsScreen(),
                      AnalysisScreen(),
                      LoanManagementScreen(),
                      ProfileHubScreen(),
                    ],
                  ),
                  Consumer2<TransactionsViewModel, LoansViewModel>(
                    builder: (context, txVM, loansVM, _) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, _) {
                          return _buildFlyingCardsOverlay(
                            context,
                            settingsVM,
                            txVM,
                            loansVM,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              bottomNavigationBar: (navData.isMenuOpen || isKeyboardOpen)
                  ? const SizedBox.shrink()
                  : CustomBottomNavBar(
                      currentIndex: currentIndex,
                      pageController: _pageController,
                      onTap: (index) => _onNavTap(index, settingsVM),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlyingCardsOverlay(
    BuildContext context,
    SettingsViewModel settingsVM,
    TransactionsViewModel txVM,
    LoansViewModel loansVM,
  ) {
    final double page = _pageController.hasClients
        ? (_pageController.page ?? 0.0)
        : settingsVM.pageOffset;
    final t = page.clamp(0.0, 1.0);

    // Hide when resting on Home (t <= 0.02) or resting on/beyond Wallet Page (t >= 0.98 || page >= 0.98)
    if (t <= 0.02 || t >= 0.98 || page >= 0.98) return const SizedBox.shrink();

    final senders = txVM.senders;
    if (senders.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;
    final overdueOffset = loansVM.overdueLoans.isNotEmpty ? 44.0 : 0.0;
    final topScrollOffset = settingsVM.homeTopScrollOffset.clamp(0.0, double.infinity);
    final deckTop = topPadding + 68.0 + overdueOffset - topScrollOffset;

    // Dynamic ordered card list: active bank senders + Cash Wallet + paused bank senders
    final orderedNames = txVM.orderedWalletNames;
    final int totalCards = orderedNames.length;
    final int activeCount = txVM.activeSenders.length;
    final bool hasPaused = txVM.pausedSenders.isNotEmpty;

    // Home deck (t=0.0) left-offset pattern matching DashboardScreen
    const double baseLeftOffset = -42.0;
    const double leftStep = 22.0;

    final List<Widget> cardWidgets = [];

    for (int i = 0; i < totalCards; i++) {
      final String cardName = orderedNames[i];
      final bool isCashWallet = cardName == 'Cash Wallet';
      final bool isPaused =
          isCashWallet ? false : txVM.isTrackingPaused(cardName);
      // Only the first 3 active bank senders are visible on the Home page deck
      final bool isVisibleOnHome = !isPaused && !isCashWallet && i < 3;

      // ── Wallet list position (t=1.0) ──────────────────────────────
      const double walletLeft = 0.0;
      final double headerOffset = (hasPaused && i > activeCount) ? 36.0 : 0.0;
      final double walletTop = topPadding + 62.0 + i * 186.0 + headerOffset;
      final double walletW = screenWidth;
      const double walletH = 172.0;

      // ── Home deck position (t=0.0) ────────────────────────────────
      // Visible-on-Home cards get their own stacked offset; all others
      // collapse behind the last visible deck card.
      final int deckIndex =
          isVisibleOnHome ? i : 2.clamp(0, activeCount > 0 ? activeCount - 1 : 0);
      final double deckLeftOffset = baseLeftOffset + deckIndex * leftStep;
      final double homeLeft = screenWidth - 105.0 + deckLeftOffset + 42.0;
      const double homeW = 104.0;
      const double homeH = 188.0;

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
      final double balance = txVM.balanceForSender(cardName);
      final int txCount = txVM.txCountForSender(cardName);
      final bool cardBalanceVisible =
          settingsVM.isBalanceVisible && !settingsVM.isBankBalanceHidden(cardName);

      final int homeDeckTopIndex =
          activeCount > 0 ? (activeCount.clamp(1, 3) - 1) : -1;
      final bool isTopCard = (i == homeDeckTopIndex);

      final Widget card = BankCardWidget(
        senderName: cardName,
        balance: balance,
        txCount: txCount,
        isBalanceVisible: cardBalanceVisible,
        isPaused: isPaused,
        isTopCard: isTopCard,
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
                  settingsVM.animateToTab(1);
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
