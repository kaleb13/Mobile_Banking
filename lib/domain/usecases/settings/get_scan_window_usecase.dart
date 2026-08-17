import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/scan_window_option.dart';

/// Result containing the active scan window option and its hard anchor boundary.
class ScanWindowInfo {
  final ScanWindowOption option;
  final DateTime anchorDate;
  final DateTime installDate;

  const ScanWindowInfo({
    required this.option,
    required this.anchorDate,
    required this.installDate,
  });
}

/// Use case to retrieve the user's active historical scan window setting and anchor date.
class GetScanWindowUseCase {
  const GetScanWindowUseCase();

  Future<ScanWindowInfo> call() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Retrieve install date or initialize to now
    final installDateStr = prefs.getString('app_install_date');
    DateTime installDate;
    if (installDateStr != null) {
      installDate = DateTime.tryParse(installDateStr) ?? DateTime.now();
    } else {
      installDate = DateTime.now();
      await prefs.setString('app_install_date', installDate.toIso8601String());
    }

    final optionKey = prefs.getString('scan_window_option_v1');
    final option = ScanWindowOption.fromString(optionKey);

    final anchorDateStr = prefs.getString('install_anchor_date');
    DateTime anchorDate;
    if (anchorDateStr != null) {
      anchorDate = DateTime.tryParse(anchorDateStr) ?? option.computeAnchorDate(installDate);
    } else {
      anchorDate = option.computeAnchorDate(installDate);
      await prefs.setString('install_anchor_date', anchorDate.toIso8601String());
    }

    return ScanWindowInfo(
      option: option,
      anchorDate: anchorDate,
      installDate: installDate,
    );
  }
}
