import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildStep(
                    icon: Icons.shield_outlined,
                    title: 'Terms & Privacy',
                    description:
                        'By continuing, you agree to allow Shibre to process your bank SMS messages locally. Your data is encrypted and never leaves your device.',
                    buttonLabel: 'I Agree & Continue',
                    onAction: _nextPage,
                  ),
                  _buildStep(
                    icon: Icons.sms_outlined,
                    title: 'SMS Permission',
                    description:
                        'To automatically track your transactions, we need to read incoming bank messages. This allows for real-time balance updates.',
                    buttonLabel: 'Grant SMS Access',
                    onAction: () async {
                      // Request SMS permission directly — do NOT call
                      // provider.requestPermission() here, as that triggers
                      // init() which sets isLoading=true and destroys this
                      // page's widget state, resetting back to page 0.
                      final status = await Permission.sms.request();
                      // Also request notifications while we're at it
                      await Permission.notification.request();
                      if (status.isGranted) {
                        _nextPage();
                      } else if (mounted) {
                        _showErrorSnackBar(
                            'SMS permission is required to continue.');
                      }
                    },
                  ),
                  _buildStep(
                    icon: Icons.backup_outlined,
                    title: 'Data Safety',
                    description:
                        'We recommend granting storage access to enable automatic backups. This ensures you can restore your data if you switch devices.',
                    buttonLabel: 'Grant Access & Finish',
                    onAction: () async {
                      final provider =
                          Provider.of<FinanceProvider>(context, listen: false);
                      await provider.requestStoragePermission();
                      // Mark onboarding complete — the Consumer in main.dart
                      // will then rebuild and call init() properly.
                      await provider.completeOnboarding();
                    },
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 72, color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 16,
              height: 1.6,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: const Color(0xFF0A0B0D),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = _currentPage == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? AppColors.primaryBlue
                  : Colors.white.withOpacity(0.1),
            ),
          );
        }),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.alertRed.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}
