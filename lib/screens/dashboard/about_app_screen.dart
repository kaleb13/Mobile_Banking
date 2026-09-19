import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scroll_header_bar.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spacer for the pinned scroll header bar
                  const SizedBox(height: 54),
                  const SizedBox(height: 8),
                  _buildDeveloperCard(),
                  const SizedBox(height: 28),
                  _buildSectionLabel('ABOUT SHIBRE'),
                  _buildAboutContent(),
                ],
              ),
            ),
          ),
          // Pinned Collapsing Header Bar on Scroll
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppScrollHeaderBar(
              scrollController: _scrollController,
              title: 'About App',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/developer.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kaleb Tesfaye',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Developer and UI/UX Designer of Shibre',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _launchTelegram,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded,
                            color: AppColors.info, size: 12),
                        SizedBox(width: 6),
                        Text(
                          '@Shi_bre',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSoft,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAboutContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Text(
        'Shibre is an advanced SMS tracking application designed to simplify your financial management. It automatically parses and categorizes bank notifications from your supported banks and mobile money wallets, providing you with real-time balance tracking and detailed spending analytics. All SMS financial processing is executed strictly on-device to guarantee your financial privacy.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 14,
          height: 1.7,
        ),
      ),
    );
  }

  Future<void> _launchTelegram() async {
    final Uri tgAppUrl = Uri.parse('tg://resolve?domain=Shi_bre');
    try {
      if (await canLaunchUrl(tgAppUrl)) {
        await launchUrl(tgAppUrl, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
    } catch (_) {}

    final Uri url = Uri.parse('https://t.me/Shi_bre');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
