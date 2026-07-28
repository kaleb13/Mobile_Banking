import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/carousel_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScrollController _termsScrollController = ScrollController();
  int _currentPage = 0;
  bool _isTermsAccepted = false;
  bool _bgInitStarted = false;
  bool _isAutoProceedingToReveal = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _termsScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage == 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _kickOffBackgroundInit() {
    if (_bgInitStarted) return;
    _bgInitStarted = true;
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    provider.startBackgroundInit();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.negative,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPage == 1) {
          _previousPage();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Shared Background Graphics Composition
            _buildBackgroundStack(),

            // 2. PageView for Page Body Contents (NeverScrollable to enforce button flow)
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                if (index == 2) {
                  _kickOffBackgroundInit();
                }
              },
              children: [
                _buildWelcomePageBody(),
                _buildTermsPageBody(),
                _buildCalculatingPageBody(),
                _buildLevelRevealPageBody(),
              ],
            ),

            // 3. Fixed Bottom Area (Carousel Indicator + Action Button)
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF071410), Color(0xFF050C16), Color(0xFF060D0A)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Entire background graphic composition with 50% opacity
        Opacity(
          opacity: 0.50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background ambient fading glow (vertical oval)
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
              // Green foreground icon shape
              Positioned(
                top: -60,
                bottom: 60,
                right: -280,
                child: Center(
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(
                      'assets/images/launcher_foreground.png',
                      width: 680,
                    ),
                  ),
                ),
              ),
              // White outline SVG overlay
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
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0, height: 350,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF050C16)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- PAGE 0: WELCOME PAGE ---
  Widget _buildWelcomePageBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 3),
            Text(
              'Shibre',
              style: TextStyle(
                color: AppColors.telebirrGreen,
                fontSize: 14,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage your\nfinances with smart\ntracking.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Shibre analyzes your income, expenses, and financial habits to estimate your current financial level. Tap Get Started to discover where you stand and begin your journey toward a stronger financial future.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 13,
                height: 1.20,
              ),
            ),
            const Spacer(flex: 5),
          ],
        ),
      ),
    );
  }

  // --- PAGE 1: TERMS & PRIVACY + PERMISSION PAGE ---
  Widget _buildTermsPageBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back arrow
            Row(
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.telebirrGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.telebirrGreen.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, color: AppColors.telebirrGreen, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Legal',
                        style: TextStyle(color: AppColors.telebirrGreen, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Terms & Privacy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please read and accept the terms below to grant access.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable Bounded Terms Card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    controller: _termsScrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTermsSection(
                          'Data Privacy & Security',
                          'Shibre processes your bank SMS messages entirely on your device. Your financial data is stored locally and encrypted. We never transmit, sell, or share your personal or financial information with any third party.',
                        ),
                        _buildTermsSection(
                          'SMS Permission & Access',
                          'By granting SMS access, you allow Shibre to read banking messages from recognized senders (CBE, Telebirr, CBE Birr, Ahadu Bank). This permission is used exclusively for transaction detection, level estimation, and expense tracking.',
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: _isTermsAccepted
                      ? AppColors.telebirrGreen.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isTermsAccepted
                        ? AppColors.telebirrGreen.withValues(alpha: 0.40)
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isTermsAccepted,
                        activeColor: AppColors.telebirrGreen,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.50),
                          width: 1.5,
                        ),
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
                    const Expanded(
                      child: Text(
                        'I agree and accept the terms & conditions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.07)),
        ],
      ),
    );
  }

  // --- PAGE 2: CALCULATING / TRANSITIONAL PAGE ---
  Widget _buildCalculatingPageBody() {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        if (!provider.isLoading && _currentPage == 2 && !_isAutoProceedingToReveal) {
          _isAutoProceedingToReveal = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentPage == 2) {
              _pageController.animateToPage(
                3,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              );
            }
          });
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.telebirrGreen.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.telebirrGreen.withValues(alpha: 0.35),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.telebirrGreen.withValues(alpha: 0.20),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: AppColors.telebirrGreen,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'Calculating your financial level…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'We\'re scanning your banking messages and calculating your financial level and total balance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- PAGE 3: LEVEL REVEAL PAGE ---
  Widget _buildLevelRevealPageBody() {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !_isAutoProceedingToReveal) {
          return _buildCalculatingPageBody();
        }

        final level = provider.userLevel;
        final levelName = provider.userLevelName;
        final levelDesc = provider.userLevelDescription;
        final totalBalance = provider.totalBalance;
        final balancesMap = provider.latestBalancesMap;
        final cashBalance = provider.cashBalance;
        final levelColor = _levelColor(level);
        final badgePath = 'assets/images/LV$level.svg';

        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: levelColor.withValues(alpha: 0.40),
                              blurRadius: 70,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(badgePath, width: 150, height: 150),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        levelName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Level $level',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.50),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Total Amount',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTotalAmountDisplay(totalBalance),
                const SizedBox(height: 8),
                Text(
                  levelDesc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 13,
                    height: 1.60,
                  ),
                ),
                const SizedBox(height: 24),
                if (balancesMap.isNotEmpty || cashBalance > 0) ...[
                  Text(
                    'How we calculated this',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...balancesMap.entries.map((e) => _buildBankRow(e.key, e.value, levelColor)),
                  if (cashBalance > 0) _buildBankRow('Cash Wallet', cashBalance, levelColor),
                  const SizedBox(height: 4),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_formatAmount(totalBalance)} ETB',
                          style: TextStyle(
                            color: levelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
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

  // --- FIXED BOTTOM SECTION ---
  Widget _buildFixedBottomSection() {
    final isCalculatingPage = _currentPage == 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Morphing Carousel Indicator (morphs dots dynamically)
            Center(
              child: CarouselPageIndicator(
                controller: _pageController,
                pageCount: 4,
              ),
            ),
            const SizedBox(height: 18),

            // Action Button
            if (!isCalculatingPage) ...[
              _buildPillButton(
                label: _getButtonLabelForPage(_currentPage),
                enabled: _isButtonEnabledForPage(_currentPage),
                onTap: () {
                  if (_currentPage == 0) {
                    _nextPage();
                  } else if (_currentPage == 1) {
                    _handleSmsPermissionAndProceed();
                  } else if (_currentPage == 3) {
                    HapticFeedback.mediumImpact();
                    final p = Provider.of<FinanceProvider>(context, listen: false);
                    p.completeOnboarding();
                  }
                },
              ),
            ] else ...[
              // Processing bar on calculating page
              Container(
                height: 58,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.telebirrGreen),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Analyzing transactions…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 14,
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
  }

  String _getButtonLabelForPage(int page) {
    switch (page) {
      case 0:
        return 'Get started';
      case 1:
        return 'Grant SMS permission';
      case 3:
        return 'See Your Level';
      default:
        return 'Continue';
    }
  }

  bool _isButtonEnabledForPage(int page) {
    switch (page) {
      case 0:
        return true;
      case 1:
        return _isTermsAccepted;
      case 3:
        return true;
      default:
        return false;
    }
  }

  // --- BUTTON BUILDER ---
  Widget _buildPillButton({
    required String label,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final bool isClickable = enabled && onTap != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: isClickable
            ? AppColors.telebirrGreen
            : AppColors.telebirrGreen.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isClickable
              ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isClickable
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.40),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (isClickable) ...[
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAmountDisplay(double amount) {
    final s = amount.toStringAsFixed(2).split('.');
    final whole = _formatWholeNumber(s[0]);
    final decimal = s[1];
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: whole, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
          TextSpan(text: '.$decimal', style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 28, fontWeight: FontWeight.w600)),
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
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
            child: Icon(_bankIcon(bankName), color: Colors.white.withValues(alpha: 0.60), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(bankName, style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 14, fontWeight: FontWeight.w500))),
          Text('${_formatAmount(balance)} ETB', style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _levelColor(int level) {
    switch (level) {
      case 1: return const Color(0xFFE57373);
      case 2: return const Color(0xFFFFB74D);
      case 3: return const Color(0xFFFFD54F);
      case 4: return const Color(0xFF81C784);
      case 5: return const Color(0xFF4FC3F7);
      case 6: return const Color(0xFFBA68C8);
      default: return AppColors.telebirrGreen;
    }
  }

  IconData _bankIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('cbe')) return Icons.account_balance;
    if (n.contains('telebirr')) return Icons.phone_android;
    if (n.contains('ahadu')) return Icons.account_balance_wallet;
    if (n.contains('boa') || n.contains('abyssinia')) return Icons.domain;
    if (n.contains('dashen')) return Icons.store;
    if (n.contains('coop')) return Icons.groups;
    if (n.contains('cash')) return Icons.payments;
    return Icons.account_balance;
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
