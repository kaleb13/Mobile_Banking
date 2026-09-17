import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'bank_registry.dart';

/// Service for checking and downloading OTA bank rule and branding updates.
///
/// Designed with cross-version safety:
/// - Uses standard dart:io HttpClient (zero external dependencies)
/// - Rejects newer incompatible schemaVersions
/// - Validates JSON structure before persisting
/// - Atomically saves manifest to local storage
/// - Caches dynamic bank SVG icons locally
class BankSyncService {
  BankSyncService._();
  static final BankSyncService instance = BankSyncService._();

  /// Primary backend endpoint (defaults to AppConfig.banksManifestUrl: https://api.shibre.com/api/v1/banks/manifest).
  /// Can be overridden at build-time via --dart-define=BANK_MANIFEST_URL=...
  /// or at runtime via [setPrimaryEndpoint].
  String primaryManifestUrl = AppConfig.banksManifestUrl;

  /// Secondary fallback mirror (CDN / GitHub raw) if primary backend is unreachable.
  static String get fallbackManifestUrl => AppConfig.fallbackManifestUrl;

  /// Configures the primary remote endpoint dynamically at runtime.
  void setPrimaryEndpoint(String url) {
    if (url.trim().isNotEmpty) {
      primaryManifestUrl = url.trim();
    }
  }

  /// Checks the cloud endpoint for newer bank rules or newly added banks.
  /// First tries the primary endpoint, then automatically fails over to the fallback mirror.
  Future<bool> checkForUpdates({String? customUrl}) async {
    final targetUrl = customUrl ?? primaryManifestUrl;
    final success = await _fetchAndApply(targetUrl);
    if (success) return true;

    // Failover: if primary endpoint was not the fallback mirror, try the fallback mirror
    if (targetUrl != fallbackManifestUrl && customUrl == null) {
      return await _fetchAndApply(fallbackManifestUrl);
    }
    return false;
  }

  Future<bool> _fetchAndApply(String urlString) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final uri = Uri.parse(urlString);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        return false;
      }

      final content = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(content) as Map<String, dynamic>;

      final remoteSchema = decoded['schemaVersion'] as int? ?? 1;
      // Guard against future incompatible schemas on older app versions
      if (remoteSchema > BankRegistry.instance.schemaVersion) {
        return false;
      }

      final remoteRulesVer = decoded['rulesVersion'] as int? ?? 0;
      if (remoteRulesVer <= BankRegistry.instance.rulesVersion) {
        // Already up-to-date
        return false;
      }

      // Download and cache any dynamic bank icons
      final banks = decoded['banks'] as List<dynamic>? ?? [];
      final appDir = await getApplicationDocumentsDirectory();
      final assetsDir = Directory('${appDir.path}/bank_assets');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      for (final b in banks) {
        if (b is Map<String, dynamic>) {
          final branding = b['branding'] as Map<String, dynamic>?;
          final iconUrl = branding?['iconUrl'] as String?;
          final bankId = b['id'] as String?;

          if (iconUrl != null && iconUrl.isNotEmpty && bankId != null) {
            try {
              final iconUri = Uri.parse(iconUrl);
              final iconReq = await client.getUrl(iconUri);
              final iconRes = await iconReq.close();
              if (iconRes.statusCode == 200) {
                final iconFile = File('${assetsDir.path}/$bankId.svg');
                final bytes = await iconRes.fold<List<int>>(<int>[], (acc, data) => acc..addAll(data));
                await iconFile.writeAsBytes(bytes);
                branding?['localIconPath'] = iconFile.path;
              }
            } catch (_) {
              // Icon download failure is non-fatal; fallback assets will be used
            }
          }
        }
      }

      // Re-encode with any cached local icon paths
      final updatedJson = jsonEncode(decoded);

      // Save atomically to local storage in app_flutter
      final otaFile = File('${appDir.path}/${BankRegistry.manifestFileName}');
      final tempFile = File('${appDir.path}/${BankRegistry.manifestFileName}.tmp');
      await tempFile.writeAsString(updatedJson);
      if (await otaFile.exists()) {
        await otaFile.delete();
      }
      await tempFile.rename(otaFile.path);

      // Also copy to Android native files directory so Kotlin background receiver sees it immediately
      try {
        final nativeFilesDir = Directory('${appDir.parent.path}/files');
        if (await nativeFilesDir.exists()) {
          final nativeFile = File('${nativeFilesDir.path}/${BankRegistry.manifestFileName}');
          await nativeFile.writeAsString(updatedJson);
        }
      } catch (_) {}

      // Reload registry with new rules
      BankRegistry.instance.loadFromJsonString(updatedJson);
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
