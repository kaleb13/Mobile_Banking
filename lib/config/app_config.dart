/// Centralized application & backend configuration.
///
/// Anchored to the primary production domain: `shibre.com`.
/// Supports compile-time environment overrides (e.g. `--dart-define=API_BASE_URL=...`)
/// for seamless switching between local development, staging, and production.
class AppConfig {
  AppConfig._();

  /// The root production domain for the application.
  static const String baseDomain = 'shibre.com';

  /// Primary API base URL (e.g. Laravel REST API).
  ///
  /// Can be overridden at build-time using:
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` (Android Emulator local dev)
  /// or `--dart-define=API_BASE_URL=https://staging.shibre.com/api/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.shibre.com/api/v1',
  );

  /// Endpoint for Over-The-Air bank definitions, regex rules, and branding metadata.
  static String get banksManifestUrl => String.fromEnvironment(
    'BANK_MANIFEST_URL',
    defaultValue: '$apiBaseUrl/banks/manifest',
  );

  /// CDN / Mirror fallback URL if the primary shibre.com backend is temporarily offline.
  static const String fallbackManifestUrl =
      'https://raw.githubusercontent.com/kaleb13/Mobile_Banking/main/assets/banks_manifest.json';

  /// Static assets base URL (e.g. for remote bank SVG logos or web resources).
  static String get assetsBaseUrl => 'https://assets.shibre.com';

  /// Official support & web landing URLs
  static const String websiteUrl = 'https://shibre.com';
  static const String privacyPolicyUrl = 'https://shibre.com/privacy';
  static const String termsUrl = 'https://shibre.com/terms';
}
