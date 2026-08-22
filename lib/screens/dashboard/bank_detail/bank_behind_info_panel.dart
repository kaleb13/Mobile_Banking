import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'bank_metadata.dart';

/// Reusable behind-card information panel revealed when dragging down any bank card.
/// Stretches full-width behind the front card with dynamic slide height and non-clipping padding.
/// Uses the unified primary emerald green gradient across all bank/wallet sections.
class BankBehindInfoPanel extends StatelessWidget {
  final double topSafeArea;
  final double currentSlide;
  final double revealProgress;
  final BankInfoData infoData;

  /// Single unified primary gradient for the info section across the entire app
  static const List<Color> primaryGradient = AppColors.unifiedBankBehindGradient;

  const BankBehindInfoPanel({
    super.key,
    required this.topSafeArea,
    required this.currentSlide,
    required this.revealProgress,
    required this.infoData,
  });

  @override
  Widget build(BuildContext context) {
    if (revealProgress <= 0.01) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: topSafeArea + currentSlide + 36.0,
      child: Opacity(
        opacity: (revealProgress * 1.4).clamp(0.0, 1.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              18,
              topSafeArea + 18,
              18,
              24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: primaryGradient,
              ),
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: Badge & "Release to close"
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              infoData.badgeIcon,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              infoData.badgeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Release to close',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Bank / Wallet Title
                  Text(
                    infoData.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Description / Parsing Details
                  Text(
                    infoData.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
