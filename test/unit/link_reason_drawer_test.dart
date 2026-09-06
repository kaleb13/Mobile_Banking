import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/screens/dashboard/reason_link_drawer.dart';

void main() {
  testWidgets('LinkReasonDrawer renders in standalone mode without Provider',
      (tester) async {
    LinkScope? selectedScopeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  LinkReasonDrawer.show(
                    context: context,
                    reasonId: 101,
                    reasonName: 'Breakfast',
                    contactName: 'Abebe',
                    linkType: 'receiver',
                    matchingCount: 3,
                    onSelectScope: (scope) {
                      selectedScopeResult = scope;
                    },
                  );
                },
                child: const Text('Open Modal'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open modal
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('Link "Breakfast"'), findsOneWidget);
    expect(find.text('3 txs'), findsOneWidget);
    expect(find.text('SELECT LINKING SCOPE'), findsOneWidget);
    expect(find.text('All Transactions (Past & Future)'), findsOneWidget);
    expect(find.text('From Now On (Future Only)'), findsOneWidget);

    // Tap All Transactions option
    await tester.tap(find.text('All Transactions (Past & Future)'));
    await tester.pumpAndSettle();

    expect(selectedScopeResult, LinkScope.allTransactions);
  });

  testWidgets('LinkReasonDrawer selects Future Only scope and shows Remove Rule when active',
      (tester) async {
    LinkScope? selectedScopeResult;
    bool removeRuleCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  LinkReasonDrawer.show(
                    context: context,
                    reasonId: 201,
                    reasonName: 'Coffee',
                    contactName: 'Café Kaldi',
                    linkType: 'receiver',
                    selectedScope: LinkScope.futureTransactionsOnly,
                    onSelectScope: (scope) {
                      selectedScopeResult = scope;
                    },
                    onRemoveRule: () {
                      removeRuleCalled = true;
                    },
                  );
                },
                child: const Text('Open Modal'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Remove option should be visible
    expect(find.text('Do Not Link (Remove Rule)'), findsOneWidget);

    // Tap remove rule
    await tester.tap(find.text('Do Not Link (Remove Rule)'));
    await tester.pumpAndSettle();

    expect(removeRuleCalled, isTrue);
    expect(selectedScopeResult, isNull);
  });
}
