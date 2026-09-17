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

  /// Supabase Cloud Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ysjhhbjnrzrgynzovwey.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzamhoYmpucnpyZ3luem92d2V5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk2NDAwOTMsImV4cCI6MjEwNTIxNjA5M30.tyvoIWUx8_zeV8SFhMy8Tsoo_dmDDP-NbDop9A-4OZY',
  );

  /// Google OAuth Client IDs
  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: '801642797876-a18he8o60t14frsf1v756ru4vc2sh3s6.apps.googleusercontent.com',
  );

  static const String googleAndroidReleaseClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_RELEASE_CLIENT_ID',
    defaultValue: '801642797876-6aeo924a0ead9mho6sa86rbf5isjqrjq.apps.googleusercontent.com',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '801642797876-hh33mt126n8r6q0bk4d4tf6pjis9ic1c.apps.googleusercontent.com',
  );
}
