import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/finance_provider.dart';
import 'theme/app_theme.dart';
import 'screens/shell/main_shell.dart';
import 'screens/intro/onboarding_screen.dart';
import 'screens/privacy/app_lock_screen.dart';
import 'services/pin_service.dart';
import 'screens/dashboard/quick_edit_overlay.dart';

/// Global navigator key — allows non-widget code (e.g. FinanceProvider) to
/// push routes or show modals without needing a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'appNavigatorKey');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SMS handling is now done natively by SmsBroadcastReceiver.kt —
  // no Dart-side background service startup needed.

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone =
      prefs.getBool('is_onboarding_complete_v1') ?? false;

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final String? savedTheme = prefs.getString('app_theme_mode');
  AppThemeMode initialTheme = AppThemeMode.hybrid;
  if (savedTheme == 'light') initialTheme = AppThemeMode.light;
  if (savedTheme == 'dark') initialTheme = AppThemeMode.dark;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FinanceProvider(
            initialOnboardingComplete: onboardingDone,
            initialThemeMode: initialTheme,
          )..init(),
        ),
      ],
      child: const MobileBankingApp(),
    ),
  );
}

class MobileBankingApp extends StatefulWidget {
  const MobileBankingApp({super.key});

  @override
  State<MobileBankingApp> createState() => _MobileBankingAppState();
}

class _MobileBankingAppState extends State<MobileBankingApp> {
  bool _isLocked = false;
  bool _checkedOnStart = false;

  @override
  void initState() {
    super.initState();
    _checkInitialLock();
  }

  Future<void> _checkInitialLock() async {
    final locked = await PinService.instance.isLockEnabled();
    if (mounted) {
      setState(() {
        _isLocked = locked;
        _checkedOnStart = true;
      });
    }
  }

  void _unlock() {
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'Shibre',
          theme: AppTheme.themeFor(provider.currentThemeMode),
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          home: !_checkedOnStart
              ? Scaffold(backgroundColor: AppColors.background)
              : _isLocked
                  ? AppLockScreen(onUnlocked: _unlock)
                  : !provider.isOnboardingComplete
                      ? const OnboardingScreen()
                      : const MainShell(),
        );
      },
    );
  }
}

// ─── Quick Edit Overlay Entry Point ──────────────────────────────────────────
// Separate Dart entry point for TransactionQuickEditActivity.
// Must live in main.dart so the AOT compiler includes it in the release snapshot.
// The @pragma prevents tree-shaking since nothing in main() calls this.

@pragma('vm:entry-point')
void quickEditMain() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const QuickEditOverlay(),
    ),
  );
}

