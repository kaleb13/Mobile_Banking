import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F25),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About App',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeveloperCard(),
            const SizedBox(height: 32),
            _buildSectionLabel('CONTRIBUTOR'),
            _buildContributorCard('Kaleab Afesha Abayneh'),
            const SizedBox(height: 32),
            _buildSectionLabel('ABOUT SHIBRE'),
            _buildAboutContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF0B90B), width: 2),
            ),
            child: const CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage('assets/images/developer.jpg'),
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
                    color: Colors.white.withOpacity(0.5),
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
                      color: const Color(0xFF64B5F6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded,
                            color: Color(0xFF64B5F6), size: 12),
                        SizedBox(width: 6),
                        Text(
                          '@zkaleb',
                          style: TextStyle(
                            color: Color(0xFF64B5F6),
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
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.labelGray,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildContributorCard(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: AppColors.labelGray, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(
        'Shibre is an advanced SMS tracking application designed to simplify your financial management. It automatically parses and categorizes bank notifications from CBE, Telebirr, and CBE Birr, providing you with real-time balance tracking and detailed spending analytics. All processing is done strictly offline to ensure your financial privacy.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
          height: 1.7,
        ),
      ),
    );
  }

  Future<void> _launchTelegram() async {
    final Uri url = Uri.parse('https://t.me/zkaleb');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Fallback or log error
    }
  }
}
