import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_banking_app/screens/dashboard/profile_hub_screen.dart';
import 'package:mobile_banking_app/widgets/interactive_3d_badge.dart';
import 'package:mobile_banking_app/presentation/viewmodels/auth_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/analytics_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Diagnose ProfileHubScreen render error', (tester) async {
    FlutterError.onError = (details) {
      debugPrint('FLUTTER_ERROR_CAUGHT: ${details.exceptionAsString()}');
      debugPrint('STACK: ${details.stack}');
    };

    final authVM = AuthViewModel();
    final analyticsVM = AnalyticsViewModel();
    final settingsVM = SettingsViewModel(repository: MockSettingsRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authVM),
          ChangeNotifierProvider<AnalyticsViewModel>.value(value: analyticsVM),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileHubScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    debugPrint('Test pump finished successfully without throwing!');

    // Verify Interactive3DBadge is rendered on the avatar with size 34
    final badgeFinder = find.byType(Interactive3DBadge);
    expect(badgeFinder, findsOneWidget);
    final Interactive3DBadge badgeWidget = tester.widget(badgeFinder);
    expect(badgeWidget.size, 34.0);

    // Verify no add icon is present on the avatar
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });
}
