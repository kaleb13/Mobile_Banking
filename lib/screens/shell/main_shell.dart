import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/analysis_screen.dart';
import '../dashboard/settings_screen.dart';
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
  }

  @override
  void dispose() {
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
    // Clamp to visible nav pages (0-4)
    if (index < _pageCount) {
      provider.setScreenIndex(index);
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
              body: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (index) => _onPageChanged(index, provider),
                children: const [
                  // Order: Home | Wallet | Analysis | Loans | Settings
                  DashboardScreen(),
                  WalletsScreen(),
                  AnalysisScreen(),
                  LoanManagementScreen(),
                  SettingsScreen(),
                ],
              ),
              bottomNavigationBar: (provider.isMenuOpen || isKeyboardOpen)
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "New Loan" action bar — shown only on the Loans tab (index 3)
                        if (currentIndex == 3)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 20, right: 20, bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => AddLoanSheet(
                                      provider:
                                          context.read<FinanceProvider>()),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    width: double.infinity,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.gold.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: AppColors.textPrimary
                                            .withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add,
                                            color: AppColors.brownDark,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'New Loan',
                                          style: TextStyle(
                                              color: AppColors.brownDark,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Bottom navigation pill
                        CustomBottomNavBar(
                          currentIndex: currentIndex,
                          pageController: _pageController,
                          onTap: (index) => _onNavTap(index, provider),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
