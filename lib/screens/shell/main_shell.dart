import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          return Scaffold(
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
                                    provider: context.read<FinanceProvider>()),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0B90B),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                      DynamicNavBarWrapper(
                        currentIndex: provider.currentScreenIndex,
                        onTap: (index) => _onTap(index, provider),
                        isDynamic: false,
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
