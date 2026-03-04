import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/finance_provider.dart';
import 'theme/app_theme.dart';
import 'screens/shell/main_shell.dart';
import 'screens/intro/onboarding_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();

  // Read the onboarding flag BEFORE runApp() so the first frame
  // already has the correct value — no flash of the OnboardingScreen.
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone =
      prefs.getBool('is_onboarding_complete_v1') ?? false;

  // Make the app immersive (Edge to Edge)
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

class MobileBankingApp extends StatelessWidget {
  const MobileBankingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shibre',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<FinanceProvider>(
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
