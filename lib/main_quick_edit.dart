import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard/quick_edit_overlay.dart';

/// Separate Flutter entry point for the transparent quick-edit Activity.
///
/// This is invoked by [TransactionQuickEditActivity.kt] which overrides
/// `getDartEntrypointFunctionName()` to return "quickEditMain".
///
/// This entry point is intentionally minimal — no Provider tree, no full
/// app initialization. The overlay widget communicates directly with the
/// native Activity via MethodChannel.
@pragma('vm:entry-point')
void quickEditMain() {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status / nav bars to match the floating dialog aesthetic
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const _QuickEditApp());
}

class _QuickEditApp extends StatelessWidget {
  const _QuickEditApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const QuickEditOverlay(),
    );
  }
}
