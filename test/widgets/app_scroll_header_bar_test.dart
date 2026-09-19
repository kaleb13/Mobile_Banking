import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';
import 'package:mobile_banking_app/widgets/app_back_button.dart';
import 'package:mobile_banking_app/widgets/app_scroll_header_bar.dart';

void main() {
  group('AppScrollHeaderBar Widget Tests', () {
    testWidgets('renders back button and transitions title opacity on scroll',
        (WidgetTester tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: List.generate(
                      50,
                      (index) => Container(
                        height: 50,
                        color: index.isEven ? Colors.grey[900] : Colors.grey[850],
                        child: Text('Item $index'),
                      ),
                    ),
                  ),
                ),
                AppScrollHeaderBar(
                  scrollController: scrollController,
                  title: 'Header Title',
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
          ),
        ),
      );

      // Initially at offset 0: Back button is visible
      expect(find.byType(AppBackButton), findsOneWidget);
      expect(find.text('Header Title'), findsOneWidget);

      // Scroll down by 150px
      scrollController.jumpTo(150);
      await tester.pumpAndSettle();

      // Title and icon are still rendered with full visibility
      expect(find.text('Header Title'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('renders custom avatar squircle widget in header',
        (WidgetTester tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  child: const SizedBox(height: 1000),
                ),
                AppScrollHeaderBar(
                  scrollController: scrollController,
                  title: 'Kaleb Account',
                  icon: Container(
                    key: const ValueKey('test_avatar'),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('test_avatar')), findsOneWidget);
      expect(find.text('Kaleb Account'), findsOneWidget);
    });

    testWidgets('collapsingTitle scales font size from 22.5 to 17.0 on scroll',
        (WidgetTester tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  child: const SizedBox(height: 1000),
                ),
                AppScrollHeaderBar(
                  scrollController: scrollController,
                  title: 'Settings',
                  mode: AppScrollHeaderMode.collapsingTitle,
                ),
              ],
            ),
          ),
        ),
      );

      // At offset 0: font size is 22.5
      Text titleText = tester.widget<Text>(find.text('Settings'));
      expect(titleText.style?.fontSize, 22.5);

      // Scroll to 60px: font size scales down to 17.0
      scrollController.jumpTo(60);
      await tester.pump();

      titleText = tester.widget<Text>(find.text('Settings'));
      expect(titleText.style?.fontSize, 17.0);
    });

    testWidgets('revealOnScroll hides title at offset 0 and reveals on scroll',
        (WidgetTester tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  child: const SizedBox(height: 1000),
                ),
                AppScrollHeaderBar(
                  scrollController: scrollController,
                  title: 'Profile Hub',
                  mode: AppScrollHeaderMode.revealOnScroll,
                ),
              ],
            ),
          ),
        ),
      );

      // At offset 0: Opacity is 0.0
      Opacity titleOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Profile Hub'),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(titleOpacity.opacity, 0.0);

      // Scroll past threshold: Opacity becomes 1.0
      scrollController.jumpTo(60);
      await tester.pump();

      titleOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Profile Hub'),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(titleOpacity.opacity, 1.0);
    });
  });
}
