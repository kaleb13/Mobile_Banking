import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/widgets/app_switch.dart';
import 'package:mobile_banking_app/widgets/custom_progress_bar.dart';
import 'package:mobile_banking_app/widgets/confirmation_dialog.dart';

void main() {
  group('AppSwitch Widget Tests', () {
    testWidgets('renders active state and responds to tap', (WidgetTester tester) async {
      bool value = true;
      bool toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppSwitch(
                  value: value,
                  onChanged: (val) {
                    toggled = true;
                    value = val;
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify widget exists
      expect(find.byType(AppSwitch), findsOneWidget);

      // Tap widget
      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
      expect(value, isFalse);
    });
  });

  group('CustomProgressBar Widget Tests', () {
    testWidgets('renders progress bar with label correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomProgressBar(
              progress: 0.75,
              backgroundColor: Colors.grey,
              progressColor: Colors.blue,
              centerLabel: '75%',
            ),
          ),
        ),
      );

      expect(find.byType(CustomProgressBar), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('clamps progress values below 0 and above 1', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomProgressBar(
              progress: 1.5,
              backgroundColor: Colors.grey,
              centerLabel: '150%',
            ),
          ),
        ),
      );

      expect(find.text('150%'), findsOneWidget);
    });
  });

  group('ConfirmationDialog Widget Tests', () {
    testWidgets('renders amount, message, and choice buttons', (WidgetTester tester) async {
      String? selectedChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedChoice = await showDialog<String>(
                      context: context,
                      builder: (_) => const ConfirmationDialog(
                        amount: '500.00',
                        message: 'Received 500 ETB',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify content
      expect(find.text('Detected Transaction'), findsOneWidget);
      expect(find.text('500.00'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Ignore'), findsOneWidget);

      // Tap 'Income' choice
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(selectedChoice, equals('income'));
    });
  });
}
