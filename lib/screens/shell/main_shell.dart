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
import 'custom_bottom_nav_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  // Tracks when the user last pressed back on the home tab (double-tap exit guard)
  DateTime? _lastBackPressTime;

  // Pages kept alive via IndexedStack
  List<Widget> get _pages => const [
        DashboardScreen(),
        AnalysisScreen(),
        WalletsScreen(),
        LoanManagementScreen(),
        SettingsScreen(),
      ];

  void _onTap(int index, FinanceProvider provider) {
    provider.setScreenIndex(index);
  }

  /// Called when the Android hardware/gesture back button is pressed.
  /// Returns true if the pop should be allowed (i.e. app exit), false to block.
  Future<bool> _onWillPop(FinanceProvider provider) async {
    final currentIndex = provider.currentScreenIndex;

    // If NOT on the home tab → navigate back to home, block the pop
    if (currentIndex != 0) {
      provider.setScreenIndex(0);
      return false; // prevent exiting
    }

    // On the home tab: double-tap guard before exit
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
            backgroundColor: const Color(0xFF2A2A34),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false; // block exit on first press
    }

    // Second press within 2 s → allow exit
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

          return PopScope(
            // canPop: false means we always intercept first
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return; // already handled
              final shouldExit = await _onWillPop(provider);
              if (shouldExit && context.mounted) {
                // Allow exit by popping the root route
                SystemNavigator.pop();
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF0A0B0D),
              extendBody: true,
              body: IndexedStack(
                index: provider.currentScreenIndex,
                children: _pages,
              ),
              bottomNavigationBar: (provider.isMenuOpen || isKeyboardOpen)
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (provider.currentScreenIndex == 3)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 24, right: 24, bottom: 8),
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
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    width: double.infinity,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0B90B)
                                          .withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add,
                                            color: Color(0xFF301900), size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'New Loan',
                                          style: TextStyle(
                                              color: Color(0xFF301900),
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
                        DynamicNavBarWrapper(
                          currentIndex: provider.currentScreenIndex,
                          onTap: (index) => _onTap(index, provider),
                          isDynamic: false,
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
