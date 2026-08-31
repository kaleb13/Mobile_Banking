import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/widgets/contact_avatar.dart';

void main() {
  group('ContactAvatar Unit & Widget Tests', () {
    test('getInitial extracts correct initial across diverse names and formats', () {
      expect(ContactAvatar.getInitial('Alpha Dawit'), equals('A'));
      expect(ContactAvatar.getInitial('BEREKET LIBIYOS BERGENE'), equals('B'));
      expect(ContactAvatar.getInitial('(01335625418100) - BEREKET'), equals('B'));
      expect(ContactAvatar.getInitial('0911223344'), equals('0'));
      expect(ContactAvatar.getInitial('+251911223344'), equals('0'));
      expect(ContactAvatar.getInitial('   '), equals('?'));
      expect(ContactAvatar.getInitial(null), equals('?'));
      expect(ContactAvatar.getInitial('!Special'), equals('S'));
    });

    test('All 26 letters A-Z have unique gradients', () {
      final seenGradients = <String>{};
      for (int i = 65; i <= 90; i++) {
        final char = String.fromCharCode(i);
        final gradient = ContactAvatar.getGradientForChar(char);
        expect(gradient, isNotNull);
        expect(gradient.colors.length, greaterThanOrEqualTo(2));

        final key = gradient.colors.map((c) => c.toARGB32()).join('_');
        expect(seenGradients.contains(key), isFalse,
            reason: 'Letter $char should have a unique gradient');
        seenGradients.add(key);
      }
    });

    test('All 10 digits 0-9 have unique gradients', () {
      final seenGradients = <String>{};
      for (int i = 0; i <= 9; i++) {
        final char = i.toString();
        final gradient = ContactAvatar.getGradientForChar(char);
        expect(gradient, isNotNull);
        expect(gradient.colors.length, greaterThanOrEqualTo(2));

        final key = gradient.colors.map((c) => c.toARGB32()).join('_');
        expect(seenGradients.contains(key), isFalse,
            reason: 'Digit $char should have a unique gradient');
        seenGradients.add(key);
      }
    });

    testWidgets('ContactAvatar renders circular letter avatar correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactAvatar(
              name: 'Kaleb Afesha',
              size: 48,
            ),
          ),
        ),
      );

      expect(find.text('K'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.gradient, isNotNull);
      expect(decoration.border, isNull); // Strict no border rule
    });
  });
}
