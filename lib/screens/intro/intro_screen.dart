import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/viewmodels/notifications_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifVM = Provider.of<NotificationsViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.message_outlined,
                  size: 80, color: AppColors.gold),
              const SizedBox(height: 32),
              const Text(
                'Welcome to Smart Banking',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'To automatically track your transactions accurately, this app requests permission to read your incoming SMS messages.\n\nWithout SMS permissions, the app will not open or process transactions. Please grant this permission to continue.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              AppButton.primary(
                text: 'Grant SMS Permission',
                height: 52,
                onPressed: () async {
                  await notifVM.requestPermission();
                  if (!notifVM.hasPermission && context.mounted) {
                    AppToast.error(
                      context,
                      message: 'Permission denied',
                      subtitle: 'SMS access is required to function',
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
