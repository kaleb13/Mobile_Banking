import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/finance_provider.dart';
import 'theme/app_theme.dart';
import 'screens/shell/main_shell.dart';
import 'screens/intro/onboarding_screen.dart';
import 'screens/privacy/app_lock_screen.dart';
import 'services/background_service.dart';
import 'services/pin_service.dart';

/// Global navigator key — allows non-widget code (e.g. FinanceProvider) to
/// push routes or show modals without needing a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'appNavigatorKey');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FinanceProvider(
            initialOnboardingComplete: onboardingDone,
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
    return MaterialApp(
      title: 'Shibre',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      home: !_checkedOnStart
          ? const Scaffold(backgroundColor: AppColors.background)
          : _isLocked
              ? AppLockScreen(onUnlocked: _unlock)
              : Consumer<FinanceProvider>(
                  builder: (context, provider, child) {
                    if (!provider.isOnboardingComplete) {
                      return const OnboardingScreen();
                    }
                    return const MainShell();
                  },
                ),
    );
  }
}
