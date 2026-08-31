import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/counterparty_matcher.dart';

/// Circular contact avatar widget inspired by modern iOS & Samsung contact profiles.
///
/// Deterministically maps the initial letter (A-Z) or digit (0-9) of a contact/counterparty
/// to a unique, vibrant, borderless circular gradient with high-contrast bold typography.
class ContactAvatar extends StatelessWidget {
  /// The full contact/person name, phone number, or raw counterparty string.
  final String? name;

  /// Optional explicit letter override. If omitted, extracted automatically from [name].
  final String? letter;

  /// Diameter of the circular avatar (default: 48.0).
  final double size;

  /// Optional custom font size for the initial letter. If omitted, defaults to `size * 0.42`.
  final double? fontSize;

  /// Font weight for the letter text (default: [FontWeight.bold]).
  final FontWeight fontWeight;

  const ContactAvatar({
    super.key,
    this.name,
    this.letter,
    this.size = 48.0,
    this.fontSize,
    this.fontWeight = FontWeight.bold,
  });

  /// Extracts a clean uppercase initial character from a raw name or phone string.
  static String getInitial(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) return '?';

    // Normalize through CounterpartyMatcher first if possible
    final normalized = CounterpartyMatcher.normalize(rawName).trim();
    final candidate = normalized.isNotEmpty ? normalized : rawName.trim();

    // Find the first alphanumeric character
    final match = RegExp(r'[A-Za-z0-9]').firstMatch(candidate);
    if (match != null) {
      return match.group(0)!.toUpperCase();
    }

    return candidate.substring(0, 1).toUpperCase();
  }

  /// Returns the unique [LinearGradient] assigned to a specific letter or digit.
  static LinearGradient getGradientForChar(String char) {
    final upper = char.toUpperCase().trim();
    if (upper.isEmpty) return _fallbackGradient;

    final key = upper.substring(0, 1);
    return _letterGradients[key] ?? _fallbackGradient;
  }

  /// Convenience helper to obtain the gradient directly from a full name.
  static LinearGradient getGradientForName(String? name) {
    return getGradientForChar(getInitial(name));
  }

  @override
  Widget build(BuildContext context) {
    final initial = (letter != null && letter!.isNotEmpty)
        ? letter!.substring(0, 1).toUpperCase()
        : getInitial(name);

    final gradient = getGradientForChar(initial);
    final calculatedFontSize = fontSize ?? (size * 0.42);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.buttonPrimary,
            fontSize: calculatedFontSize,
            fontWeight: fontWeight,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  // ── Curated 26 Letter Gradients (A-Z) & 10 Number Gradients (0-9) ─────────
  static const LinearGradient _fallbackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF334155), Color(0xFF475569)],
  );

  static const Map<String, LinearGradient> _letterGradients = {
    // A: Sunset Coral & Amber Peach
    'A': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF5E62), Color(0xFFFF9966)],
    ),
    // B: Royal Cerulean & Electric Cyan
    'B': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
    ),
    // C: Emerald Sea & Fresh Mint
    'C': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    // D: Deep Violet & Royal Purple
    'D': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    ),
    // E: Electric Amber & Tangerine Glow
    'E': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
    ),
    // F: Flamingo Pink & Vivid Crimson
    'F': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    ),
    // G: Ocean Turquoise & Deep Aqua
    'G': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
    ),
    // H: Hyper Lavender & Soft Orchid
    'H': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
    ),
    // I: Cobalt Blue & Electric Azure
    'I': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
    ),
    // J: Jade Emerald & Spearmint
    'J': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0BA360), Color(0xFF3CBA92)],
    ),
    // K: Royal Amethyst & Berry Plum
    'K': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9D50BB), Color(0xFF6E48AA)],
    ),
    // L: Radiant Crimson & Magenta Flame
    'L': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
    ),
    // M: Steel Cobalt & Midnight Slate
    'M': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A7BD5), Color(0xFF3A6073)],
    ),
    // N: Neon Fuchsia & Vivid Orchid
    'N': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
    ),
    // O: Oasis Teal & Aquamarine
    'O': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF136A8A), Color(0xFF267871)],
    ),
    // P: Passion Peach & Golden Flame
    'P': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF5858), Color(0xFFF09819)],
    ),
    // Q: Rose Quartz & Raspberry Glow
    'Q': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEC008C), Color(0xFFFC6767)],
    ),
    // R: Ruby Scarlet & Ember Flame
    'R': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEB3349), Color(0xFFF45C43)],
    ),
    // S: Sapphire Blue & Electric Lavender
    'S': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4776E6), Color(0xFF8E54E9)],
    ),
    // T: Tropical Teal & Caribbean Cyan
    'T': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF02AAB0), Color(0xFF00CDAC)],
    ),
    // U: Ultraviolet & Cosmic Magenta
    'U': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7000FF), Color(0xFFD400FF)],
    ),
    // V: Vibrant Lime & Emerald Leaf
    'V': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF56AB2F), Color(0xFFA8E063)],
    ),
    // W: Cosmic Dual (Deep Ruby to Royal Navy)
    'W': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB92B27), Color(0xFF1565C0)],
    ),
    // X: Amazon Green & Neon Seafoam
    'X': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1D976C), Color(0xFF93F9B9)],
    ),
    // Y: Golden Honey & Sunburst Amber
    'Y': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
    ),
    // Z: Zenith Iris & Electric Violet
    'Z': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
    ),

    // ── Digits 0 - 9 ────────────────────────────────────────────────────────
    // 0: Slate Graphite
    '0': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF475569), Color(0xFF64748B)],
    ),
    // 1: Sky Azure
    '1': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
    ),
    // 2: Mint Emerald
    '2': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF059669), Color(0xFF10B981)],
    ),
    // 3: Warm Amber
    '3': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    ),
    // 4: Vibrant Red
    '4': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    ),
    // 5: Royal Purple
    '5': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    // 6: Pink Berry
    '6': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDB2777), Color(0xFFEC4899)],
    ),
    // 7: Ocean Cyan
    '7': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
    ),
    // 8: Spring Green
    '8': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
    ),
    // 9: Sun Tangerine
    '9': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEA580C), Color(0xFFF97316)],
    ),
  };
}
