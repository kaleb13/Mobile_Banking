import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/analysis_screen.dart';
import '../dashboard/profile_hub_screen.dart';
import '../wallets/wallets_screen.dart';
import '../loans/loan_management_screen.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
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
  }

  void _onPageScroll() {
    if (mounted && _pageController.hasClients) {
      final offset = _pageController.page ?? 0.0;
      context.read<FinanceProvider>().setPageOffset(offset);
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
    if (t <= 0.001 || t >= 0.999) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    // ── Card 1: Telebirr Green ─────────────────────────────────────────────────
    final c1StartLeft = screenWidth - 95.0 - 18.0;
    final c1StartTop = topPadding + 140.0;
    final c1StartW = 95.0;
    final c1StartH = 185.0;

    final c1TargetLeft = 16.0;
    final c1TargetTop = topPadding + 72.0;
    final c1TargetW = screenWidth - 32.0;
    final c1TargetH = 160.0;

    final c1Left = lerpDouble(c1StartLeft, c1TargetLeft, t)!;
    final c1Top = lerpDouble(c1StartTop, c1TargetTop, t)!;
    final c1W = lerpDouble(c1StartW, c1TargetW, t)!;
    final c1H = lerpDouble(c1StartH, c1TargetH, t)!;
    final c1Radius = lerpDouble(24, 22, t)!;

    // ── Card 2: CBE Brown ─────────────────────────────────────────────────────
    final c2StartLeft = screenWidth - 95.0 + 6.0;
    final c2StartTop = topPadding + 140.0;
    final c2StartW = 95.0;
    final c2StartH = 185.0;

    final c2TargetLeft = 16.0;
    final c2TargetTop = topPadding + 246.0;
    final c2TargetW = screenWidth - 32.0;
    final c2TargetH = 160.0;

    final c2Left = lerpDouble(c2StartLeft, c2TargetLeft, t)!;
    final c2Top = lerpDouble(c2StartTop, c2TargetTop, t)!;
    final c2W = lerpDouble(c2StartW, c2TargetW, t)!;
    final c2H = lerpDouble(c2StartH, c2TargetH, t)!;
    final c2Radius = lerpDouble(24, 22, t)!;

    // ── Card 3: CBE Birr White/Pink ───────────────────────────────────────────
    final c3StartLeft = screenWidth - 95.0 + 30.0;
    final c3StartTop = topPadding + 140.0;
    final c3StartW = 95.0;
    final c3StartH = 185.0;

    final c3TargetLeft = 16.0;
    final c3TargetTop = topPadding + 420.0;
    final c3TargetW = screenWidth - 32.0;
    final c3TargetH = 160.0;

    final c3Left = lerpDouble(c3StartLeft, c3TargetLeft, t)!;
    final c3Top = lerpDouble(c3StartTop, c3TargetTop, t)!;
    final c3W = lerpDouble(c3StartW, c3TargetW, t)!;
    final c3H = lerpDouble(c3StartH, c3TargetH, t)!;
    final c3Radius = lerpDouble(24, 22, t)!;

    final contentOpacity = ((t - 0.15) / 0.85).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Stack(
        children: [
          // Card 1: Telebirr
          Positioned(
            left: c1Left,
            top: c1Top,
            width: c1W,
            height: c1H,
            child: _buildFlyingCardItem(
              senderName: 'Telebirr',
              gradientColors: const [AppColors.success, AppColors.cardLime],
              radius: c1Radius,
              contentOpacity: contentOpacity,
              provider: provider,
            ),
          ),
          // Card 2: CBE
          Positioned(
            left: c2Left,
            top: c2Top,
            width: c2W,
            height: c2H,
            child: _buildFlyingCardItem(
              senderName: 'CBE',
              gradientColors: const [
                AppColors.cardBrownDark,
                AppColors.cardBrownMid
              ],
              radius: c2Radius,
              contentOpacity: contentOpacity,
              provider: provider,
            ),
          ),
          // Card 3: CBE Birr
          Positioned(
            left: c3Left,
            top: c3Top,
            width: c3W,
            height: c3H,
            child: _buildFlyingCardItem(
              senderName: 'CBE BIRR',
              gradientColors: const [
                AppColors.cardCbeBirrSilver,
                AppColors.cardCbeBirrWhite
              ],
              radius: c3Radius,
              contentOpacity: contentOpacity,
              provider: provider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlyingCardItem({
    required String senderName,
    required List<Color> gradientColors,
    required double radius,
    required double contentOpacity,
    required FinanceProvider provider,
  }) {
    final senderTxs = provider.transactions
        .where((t) => t.name.toUpperCase() == senderName.toUpperCase())
        .toList();

    double balance = 0;
    final withBal = senderTxs.where((t) => t.totalBalance > 0);
    if (withBal.isNotEmpty) {
      balance = withBal.first.totalBalance;
    }

    final fmt = NumberFormat('#,##0.00');
    final balStr =
        provider.isBalanceVisible ? fmt.format(balance) : '****,***.**';
    final parts = balStr.split('.');

    final bool isDarkText = senderName.toUpperCase().contains('AHADU') ||
        senderName.toUpperCase() == 'CBE BIRR' ||
        senderName.toUpperCase() == 'CBEBIRR';
    final Color textColor = isDarkText ? AppColors.darkCharcoal : Colors.white;
    final Color textSubColor = isDarkText
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: contentOpacity < 0.05
          ? const SizedBox.shrink()
          : Opacity(
              opacity: contentOpacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _flyingBankLogo(senderName),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        parts[0],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '.${parts[1]}',
                        style: TextStyle(
                          color: textSubColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _flyingBankLogo(String name) {
    final nameUp = name.toUpperCase();
    String imagePath = '';

    if (nameUp == 'CBE') {
      imagePath = 'assets/images/CBE logo 1.png';
    } else if (nameUp == 'TELEBIRR') {
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      imagePath = 'assets/images/CBEBirr Logo.png';
    }

    if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
      );
    }

    return Icon(
      Icons.account_balance,
      color: Colors.white.withValues(alpha: 0.9),
      size: 30,
    );
  }
}
