import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/analytics_view_model.dart';
import '../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../models/scan_progress_status.dart';
import '../../theme/app_theme.dart';
import '../../models/scan_window_option.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/carousel_page_indicator.dart';
import '../../widgets/interactive_3d_badge.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../widgets/app_toast.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

Color _levelGlowColor(int level) {
  switch (level) {
    case 1:
      return AppColors.levelGlow1;
    case 2:
      return AppColors.levelGlow2;
    case 3:
      return AppColors.levelGlow3;
    case 4:
      return AppColors.levelGlow4;
    case 5:
      return AppColors.levelGlow5;
    default:
      return AppColors.levelGlow1;
  }
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScrollController _termsScrollController = ScrollController();
  int _currentPage = 0;
  bool _isTermsAccepted = false;
  bool _bgInitStarted = false;
  ScanWindowOption _selectedScanOption = ScanWindowOption.sevenDays;

  // Scan progress animation
  late AnimationController _scanProgressController;
  late Animation<double> _scanProgressAnim;

  // Balance count-up animation
  late AnimationController _balanceCountController;
  late Animation<double> _balanceCountAnim;
  double _targetBalance = 0.0;
  bool _hasStartedCounting = false;

  @override
  void initState() {
    super.initState();

    _scanProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _scanProgressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanProgressController, curve: Curves.easeInOutCubic),
    );

    _balanceCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _balanceCountAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _balanceCountController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _termsScrollController.dispose();
    _scanProgressController.dispose();
    _balanceCountController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0 && _currentPage < 4) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _kickOffBackgroundInit() {
    if (_bgInitStarted) return;
    _bgInitStarted = true;
    _scanProgressController.forward();
    final settingsVM = Provider.of<SettingsViewModel>(context, listen: false);
    final txVM = Provider.of<TransactionsViewModel>(context, listen: false);

    settingsVM.setScanWindowOption(_selectedScanOption);
    txVM.scanSms(
      scanWindowOption: _selectedScanOption,
      onProgress: (status) {
        settingsVM.updateScanProgress(status);
      },
    );
  }

  void _triggerBalanceCountUp(double finalBalance) {
    if (_hasStartedCounting) return;
    _hasStartedCounting = true;
    _targetBalance = finalBalance;
    _balanceCountController.forward(from: 0.0);
  }

  Future<void> _handleSmsPermissionAndProceed() async {
    HapticFeedback.lightImpact();
    final status = await Permission.sms.request();
    await Permission.notification.request();

    _kickOffBackgroundInit();
    _nextPage();

    if (!status.isGranted && mounted) {
      _showError('SMS permission is required to analyze your transactions automatically.');
    }
  }

  void _showError(String message) {
    AppToast.error(
      context,
      message: 'Permission required',
      subtitle: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPage > 0 && _currentPage < 4) {
          _previousPage();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Graphics (Shown on Page 0)
            _buildBackgroundStack(),

            // 2. PageView for 5 Onboarding Pages
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                if (index == 4) {
                  _kickOffBackgroundInit();
                }
              },
              children: [
                _buildWelcomePageBody(),
                _buildSupportedBanksPageBody(),
                _buildScanWindowPageBody(),
                _buildTermsPageBody(),
                _buildLevelRevealPageBody(),
              ],
            ),

            // 3. Fixed Bottom Area (Carousel Indicator + Pill Action Button)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFixedBottomSection(),
            ),
          ],
        ),
      ),
    );
  }

  // --- BACKGROUND GRAPHICS ---
  Widget _buildBackgroundStack() {
    if (_currentPage != 0) {
      return Container(color: AppColors.background);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.onboardingDark,
                AppColors.background,
                AppColors.onboardingDeep,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Opacity(
          opacity: 0.50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -60,
                bottom: 60,
                right: -150,
                child: Center(
                  child: SizedBox(
                    width: 360,
                    height: 560,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.elliptical(180, 280)),
                          color: AppColors.telebirrGreen.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -60,
                bottom: 60,
                right: -280,
                child: Center(
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(
                      'assets/images/launcher_foreground.webp',
                      width: 680,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -60,
                bottom: 60,
                right: -100,
                child: Center(
                  child: Opacity(
                    opacity: 0.10,
                    child: SvgPicture.asset(
                      'assets/images/Shibre_Outline.svg',
                      width: 400,
                      colorFilter: ColorFilter.mode(
                        context.themeTextPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 350,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.background],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- PAGE 0: ORIGINAL HERO START SCREEN ---
  Widget _buildWelcomePageBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 124),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            const AppBadge.success(
              text: 'SMART FINANCIAL TRACKING',
              size: AppBadgeSize.small,
            ),
            const SizedBox(height: 14),
            Text(
              'Manage your finances\nwith clarity.',
              style: AppTypography.heading1.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Automatically analyze bank SMS, track spending, and discover your financial level in real time.',
              style: AppTypography.bodyMedium.copyWith(
                color: context.themeTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- PAGE 1: CLEAN SUPPORTED BANKS LIST (EDGE-TO-EDGE CARDS) ---
  Widget _buildSupportedBanksPageBody() {
    final supportedBanks = [
      {'name': 'Telebirr', 'type': 'Ethio Telecom Mobile Money'},
      {'name': 'CBE', 'type': 'Commercial Bank of Ethiopia'},
      {'name': 'BOA', 'type': 'Bank of Abyssinia'},
      {'name': 'CBE Birr', 'type': 'CBE Mobile Money Wallet'},
      {'name': 'Ahadu Bank', 'type': 'Ahadu Mobile Banking'},
      {'name': 'Dashen Bank', 'type': 'Dashen Mobile & Amole'},
      {'name': 'Cash Wallet', 'type': 'Automatic ATM cash tracker'},
    ];

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with back arrow and title (16px screen padding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppBackButton(onPressed: _previousPage),
                      const SizedBox(width: 12),
                      Text(
                        'Supported Banks',
                        style: AppTypography.heading1.copyWith(
                          color: context.themeTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shibre automatically syncs SMS from these supported Ethiopian institutions:',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.themeTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bank tiles container stretching 100% full-width edge-to-edge
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              customColor: AppColors.surface,
              borderRadius: AppRadius.card,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < supportedBanks.length; i++) ...[
                    if (i > 0)
                      Container(
                        height: 1,
                        color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: BankCardWidget.getCardGradient(
                                  supportedBanks[i]['name']!,
                                ),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: BankCardWidget.bankLogo(
                                supportedBanks[i]['name']!,
                                24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supportedBanks[i]['name']!,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: context.themeTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  supportedBanks[i]['type']!,
                                  style: AppTypography.caption.copyWith(
                                    color: context.themeTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const AppBadge.success(
                            text: 'Auto-Sync',
                            size: AppBadgeSize.micro,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Security footnote container stretching 100% full-width edge-to-edge
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              customColor: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardSm,
              child: Row(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    color: AppColors.brandGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Personal messages, private texts, and OTP codes are strictly ignored.',
                      style: AppTypography.caption.copyWith(
                        color: context.themeTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PAGE 2: HISTORICAL SCAN RANGE SELECTION (EDGE-TO-EDGE CARDS) ---
  Widget _buildScanWindowPageBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with back arrow and title (16px screen padding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppBackButton(onPressed: _previousPage),
                      const SizedBox(width: 12),
                      Text(
                        'Transaction History',
                        style: AppTypography.heading1.copyWith(
                          color: context.themeTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select how much past transaction history you want to import from your banking SMS:',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.themeTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan Options List (Cards stretching cleanly edge-to-edge)
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: ScanWindowOption.values.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final option = ScanWindowOption.values[index];
                  final bool isSelected = _selectedScanOption == option;

                  Widget? badgeWidget;
                  if (option == ScanWindowOption.sevenDays) {
                    badgeWidget = const AppBadge.success(
                      text: 'Recommended',
                      size: AppBadgeSize.micro,
                    );
                  } else if (option == ScanWindowOption.todayOnly) {
                    badgeWidget = const AppBadge.neutral(
                      text: 'Instant',
                      size: AppBadgeSize.micro,
                    );
                  } else if (option.isHeavyLoad) {
                    badgeWidget = const AppBadge.destructive(
                      text: 'Heavy Load',
                      size: AppBadgeSize.micro,
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedScanOption = option;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandGreen.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.brandGreen.withValues(alpha: 0.20)
                                  : AppColors.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getScanOptionIcon(option),
                              color: isSelected ? AppColors.brandGreen : AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        option.title,
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: isSelected
                                              ? AppColors.brandGreen
                                              : context.themeTextPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (badgeWidget != null) ...[
                                      const SizedBox(width: 6),
                                      badgeWidget,
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option.subtitle,
                                  style: AppTypography.caption.copyWith(
                                    color: context.themeTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppColors.brandGreen : Colors.transparent,
                            ),
                            child: isSelected
                                ? Icon(Icons.check, color: AppColors.buttonPrimaryText, size: 13)
                                : Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.surfaceElevated,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Performance advice card
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              customColor: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardSm,
              child: Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    color: AppColors.brandGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '7 Days or Today is recommended for instant setup and maximum smoothness across all phones.',
                      style: AppTypography.caption.copyWith(
                        color: context.themeTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getScanOptionIcon(ScanWindowOption option) {
    switch (option) {
      case ScanWindowOption.todayOnly:
        return Icons.today_rounded;
      case ScanWindowOption.sevenDays:
        return Icons.date_range_rounded;
      case ScanWindowOption.thirtyDays:
        return Icons.calendar_month_rounded;
      case ScanWindowOption.ninetyDays:
        return Icons.event_note_rounded;
      case ScanWindowOption.allTime:
        return Icons.history_rounded;
    }
  }

  // --- PAGE 3: TERMS & PRIVACY (EDGE-TO-EDGE CARDS) ---
  Widget _buildTermsPageBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with back arrow and title (16px screen padding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppBackButton(onPressed: _previousPage),
                      const SizedBox(width: 12),
                      Text(
                        'Terms & Privacy',
                        style: AppTypography.heading1.copyWith(
                          color: context.themeTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please read and accept the terms below to grant access for ${_selectedScanOption.title.toLowerCase()}.',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.themeTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable Bounded Terms Card
            Expanded(
              child: AppCard(
                padding: EdgeInsets.zero,
                customColor: AppColors.surface,
                borderRadius: AppRadius.card,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: SingleChildScrollView(
                    controller: _termsScrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTermsSection(
                          'Data Privacy & Security',
                          'Shibre processes your bank SMS messages entirely on your device. Your financial data is stored locally and encrypted. We never transmit, sell, or share your personal or financial information with any third party.',
                        ),
                        _buildTermsSection(
                          'SMS Permission & Scan Window',
                          'By granting SMS access, you allow Shibre to read banking messages from recognized senders (CBE, Telebirr, CBE Birr, Ahadu Bank, BOA, Dashen Bank) within your chosen window (${_selectedScanOption.title}). This permission is used exclusively for transaction detection, level estimation, and expense tracking.',
                        ),
                        _buildTermsSection(
                          'Local Storage & Backups',
                          'Shibre may request storage access to enable local backups of your financial data. Backups are stored on your device only and are never uploaded to external cloud servers.',
                        ),
                        _buildTermsSection(
                          'User Responsibility',
                          'Shibre is a personal financial tracking tool, not a licensed financial advisor. The insights provided are for personal reference only. Always consult a certified advisor for official financial decisions.',
                        ),
                        _buildTermsSection(
                          'Updates to Terms',
                          'We may update these terms as new features are added. Continued use of Shibre signifies your agreement to revised terms.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Checkbox section below card
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isTermsAccepted = !_isTermsAccepted;
                });
              },
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                customColor: _isTermsAccepted
                    ? AppColors.brandGreen.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: AppRadius.cardSm,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isTermsAccepted,
                        activeColor: AppColors.brandGreen,
                        checkColor: AppColors.buttonPrimaryText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isTermsAccepted = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'I agree and accept the terms & conditions',
                        style: AppTypography.bodyMedium.copyWith(
                          color: context.themeTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.heading2.copyWith(
              color: context.themeTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: AppTypography.bodySmall.copyWith(
              color: context.themeTextSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: AppColors.surfaceElevated.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  // --- PAGE 4: LEVEL REVEAL & DISCOVERY SCREEN ---
  Widget _buildLevelRevealPageBody() {
    return Consumer4<SettingsViewModel, TransactionsViewModel, AnalyticsViewModel, CashWalletViewModel>(
      builder: (context, settingsVM, txVM, analyticsVM, cashVM, _) {
        final bool isCalculating = txVM.isLoading || (!settingsVM.scanProgress.isComplete && txVM.transactions.isEmpty);

        if (isCalculating) {
          return _buildMinimalistCalculatingView(settingsVM.scanProgress);
        }

        // Trigger balance count-up animation if not yet started
        if (!_hasStartedCounting) {
          _triggerBalanceCountUp(analyticsVM.totalBalance);
        }

        final level = analyticsVM.userLevel;
        final levelName = analyticsVM.userLevelName;
        final levelDesc = analyticsVM.userLevelDescription;
        final balancesMap = analyticsVM.latestBalancesMap;
        final cashBalance = cashVM.balance;
        final glowColor = _levelGlowColor(level);
        final badgePath = 'assets/images/LV$level.svg';

        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Interactive3DBadge(
                        level: level,
                        levelName: levelName,
                        badgePath: badgePath,
                        glowColor: glowColor,
                        size: 160,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        levelName,
                        style: AppTypography.heading1.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Level $level',
                        style: AppTypography.bodyMedium.copyWith(
                          color: context.themeTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Total Amount',
                  style: AppTypography.caption.copyWith(
                    color: context.themeTextSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _balanceCountAnim,
                  builder: (context, _) {
                    final currentVal = _targetBalance * _balanceCountAnim.value;
                    return _buildTotalAmountDisplay(currentVal);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  levelDesc,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.themeTextSecondary,
                    height: 1.60,
                  ),
                ),
                const SizedBox(height: 24),
                if (balancesMap.isNotEmpty || cashBalance > 0) ...[
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    customColor: AppColors.surface,
                    borderRadius: AppRadius.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How we calculated this',
                          style: AppTypography.caption.copyWith(
                            color: context.themeTextSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...balancesMap.entries.map((e) => _buildBankRow(e.key, e.value, glowColor)),
                        if (cashBalance > 0) _buildBankRow('Cash Wallet', cashBalance, glowColor),
                        const SizedBox(height: 6),
                        Container(
                          height: 1,
                          color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: context.themeTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _balanceCountAnim,
                                builder: (context, _) {
                                  final currentVal = _targetBalance * _balanceCountAnim.value;
                                  return Text(
                                    '${_formatAmount(currentVal)} ETB',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: glowColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --- CLEAN, DIRECT CALCULATING / SCANNING VIEW WITH PROGRESS BAR & FOUND BANKS ---
  Widget _buildMinimalistCalculatingView(ScanProgressStatus scanProgress) {
    final double pct = scanProgress.progress > 0
        ? scanProgress.progress.clamp(0.05, 1.0)
        : _scanProgressAnim.value.clamp(0.05, 1.0);
    final String stageText = scanProgress.stage.isNotEmpty
        ? scanProgress.stage
        : 'Scanning verified banking messages…';
    final banks = scanProgress.scannedBanks;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyzing Bank SMS',
              style: AppTypography.heading1.copyWith(
                color: context.themeTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stageText,
              style: AppTypography.bodySmall.copyWith(
                color: context.themeTextSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Progress Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan Progress',
                  style: AppTypography.caption.copyWith(
                    color: context.themeTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.brandGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Standard Design System Linear Progress Bar
            CustomProgressBar(
              progress: pct,
              height: 8,
              progressColor: AppColors.brandGreen,
              backgroundColor: AppColors.tabBackground,
            ),
            const SizedBox(height: 32),

            // Dynamic Discovered Banks List
            if (banks.isNotEmpty) ...[
              Text(
                'DISCOVERED ACCOUNTS (${banks.length})',
                style: AppTypography.caption.copyWith(
                  color: context.themeTextSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              ...banks.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      customColor: AppColors.surface,
                      borderRadius: AppRadius.cardSm,
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: BankCardWidget.bankLogo(
                                b.bankName,
                                22,
                                context.themeTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.bankName,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: context.themeTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (b.latestBalance != null && b.latestBalance! > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Balance: ${_formatAmount(b.latestBalance!)} ETB',
                                    style: AppTypography.caption.copyWith(
                                      color: context.themeTextSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          AppBadge.success(
                            text: '${b.transactionCount} SMS scanned',
                            size: AppBadgeSize.micro,
                          ),
                        ],
                      ),
                    ),
                  )),
            ] else ...[
              AppCard(
                padding: const EdgeInsets.all(20),
                customColor: AppColors.surface,
                borderRadius: AppRadius.card,
                child: Row(
                  children: [
                    const Icon(
                      Icons.sms_rounded,
                      color: AppColors.brandGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Connecting to inbox and scanning for banking records…',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.themeTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- FIXED BOTTOM SECTION ---
  Widget _buildFixedBottomSection() {
    return Consumer2<SettingsViewModel, TransactionsViewModel>(
      builder: (context, settingsVM, txVM, _) {
        final bool isCalculatingPage4 =
            _currentPage == 4 && (txVM.isLoading || (!settingsVM.scanProgress.isComplete && txVM.transactions.isEmpty));

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 5-dot Morphing Carousel Indicator
                Center(
                  child: CarouselPageIndicator(
                    controller: _pageController,
                    pageCount: 5,
                  ),
                ),
                const SizedBox(height: 18),

                // Action Button
                if (!isCalculatingPage4) ...[
                  _buildPillButton(
                    label: _getButtonLabelForPage(_currentPage),
                    enabled: _isButtonEnabledForPage(_currentPage),
                    onTap: () {
                      if (_currentPage == 0) {
                        _nextPage();
                      } else if (_currentPage == 1) {
                        _nextPage();
                      } else if (_currentPage == 2) {
                        _nextPage();
                      } else if (_currentPage == 3) {
                        _handleSmsPermissionAndProceed();
                      } else if (_currentPage == 4) {
                        HapticFeedback.mediumImpact();
                        settingsVM.completeOnboarding();
                      }
                    },
                  ),
                ] else ...[
                  // Processing bar on calculating state
                  Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandGreen),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Importing banking records…',
                          style: AppTypography.bodyMedium.copyWith(
                            color: context.themeTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _getButtonLabelForPage(int page) {
    switch (page) {
      case 0:
        return 'Get started';
      case 1:
        return 'Continue';
      case 2:
        return 'Continue to Terms';
      case 3:
        return 'Grant SMS permission';
      case 4:
        return 'Open App';
      default:
        return 'Continue';
    }
  }

  bool _isButtonEnabledForPage(int page) {
    switch (page) {
      case 0:
        return true;
      case 1:
        return true;
      case 2:
        return true;
      case 3:
        return _isTermsAccepted;
      case 4:
        return true;
      default:
        return false;
    }
  }

  Widget _buildPillButton({
    required String label,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final bool isClickable = enabled && onTap != null;
    return AppButton.primary(
      text: label,
      trailingIcon: isClickable ? Icons.arrow_forward_rounded : null,
      height: 54,
      onPressed: isClickable ? onTap : null,
    );
  }

  Widget _buildTotalAmountDisplay(double amount) {
    final s = amount.toStringAsFixed(2).split('.');
    final whole = _formatWholeNumber(s[0]);
    final decimal = s[1];
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: whole,
            style: AppTypography.heading1.copyWith(
              color: context.themeTextPrimary,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          TextSpan(
            text: '.$decimal',
            style: AppTypography.heading2.copyWith(
              color: context.themeTextSecondary,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankRow(String bankName, double balance, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: BankCardWidget.bankLogo(
                bankName,
                20,
                context.themeTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bankName,
              style: AppTypography.bodyMedium.copyWith(
                color: context.themeTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${_formatAmount(balance)} ETB',
            style: AppTypography.bodyMedium.copyWith(
              color: context.themeTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = _formatWholeNumber(parts[0]);
    return '$whole.${parts[1]}';
  }

  String _formatWholeNumber(String whole) {
    final buf = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return buf.toString();
  }
}
