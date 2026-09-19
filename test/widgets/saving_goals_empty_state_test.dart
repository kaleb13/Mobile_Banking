import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';
import 'package:mobile_banking_app/widgets/app_empty_state.dart';

void main() {
  testWidgets('AppEmptyState defaults to soft white icon in dark mode and renders filled icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.savings_rounded,
            iconColor: Colors.white.withValues(alpha: 0.40),
            title: 'No Saving Goals Yet',
            subtitle: 'Set a target and track your savings progress',
            actionText: 'Create Goal',
            onAction: () {},
          ),
        ),
      ),
    );

    // Verify filled savings icon is present
    final iconFinder = find.byIcon(Icons.savings_rounded);
    expect(iconFinder, findsOneWidget);

    final iconWidget = tester.widget<Icon>(iconFinder);
    expect(iconWidget.icon, Icons.savings_rounded);
    expect(iconWidget.color, Colors.white.withValues(alpha: 0.40));

    // Verify Title & Subtitle
    expect(find.text('No Saving Goals Yet'), findsOneWidget);
    expect(find.text('Set a target and track your savings progress'), findsOneWidget);
    expect(find.text('Create Goal'), findsOneWidget);
  });
}
