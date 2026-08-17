import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/scan_window_option.dart';
import 'get_scan_window_usecase.dart';

/// Use case to configure the user's historical scan window and update the anchor date.
class SetScanWindowUseCase {
  const SetScanWindowUseCase();

  Future<ScanWindowInfo> call(ScanWindowOption option) async {
    final prefs = await SharedPreferences.getInstance();

    // Retrieve or establish app install date
    final installDateStr = prefs.getString('app_install_date');
    DateTime installDate;
    if (installDateStr != null) {
      installDate = DateTime.tryParse(installDateStr) ?? DateTime.now();
    } else {
      installDate = DateTime.now();
      await prefs.setString('app_install_date', installDate.toIso8601String());
    }

    final newAnchorDate = option.computeAnchorDate(installDate);

    await prefs.setString('scan_window_option_v1', option.keyName);
    await prefs.setString('install_anchor_date', newAnchorDate.toIso8601String());
    await prefs.setString('anchor_version', 'v4');

    return ScanWindowInfo(
      option: option,
      anchorDate: newAnchorDate,
      installDate: installDate,
    );
  }
}
