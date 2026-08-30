import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';

class MockTransactionRepoWithLinks implements TransactionRepository {
  List<AppSender> senders = [];
  List<AppTransaction> transactions = [];
  List<AppReason> reasons = [];
  List<AppReasonLink> reasonLinks = [];
  Set<String> pausedBanks = {};

  @override
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) async => List.from(transactions);
  @override
  Future<List<AppSender>> getSenders() async => List.from(senders);
  @override
  Future<List<AppReason>> getReasons() async => List.from(reasons);
  @override
  Future<List<AppReasonLink>> getReasonLinks() async => List.from(reasonLinks);
  @override
  Future<Set<String>> getPausedBanks() async => pausedBanks;
  @override
  Future<void> setPausedBanks(Set<String> paused) async => pausedBanks = paused;

  @override
  Future<List<TransactionSplit>> getAllTransactionSplits() async => [];
  @override
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId) async => [];

  @override
  Future<int> insertReasonLink(AppReasonLink link) async {
    final newId = reasonLinks.length + 1;
    reasonLinks.add(AppReasonLink(
      id: newId,
      reasonId: link.reasonId,
      linkedName: link.linkedName,
      linkType: link.linkType,
    ));
    return newId;
  }

  @override
  Future<int> deleteReasonLink(int id) async {
    final prev = reasonLinks.length;
    reasonLinks.removeWhere((l) => l.id == id);
    return prev - reasonLinks.length;
  }

  @override
  Future<int> deleteReason(int id) async {
    final prev = reasons.length;
    reasons.removeWhere((r) => r.id == id || r.parentId == id);
    return prev - reasons.length;
  }

  @override
  Future<int> updateTransaction(AppTransaction tx) async {
    final idx = transactions.indexWhere((t) => t.id == tx.id);
    if (idx != -1) {
      transactions[idx] = tx;
      return 1;
    }
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Linked Persons & Deletion Protection Tests', () {
    late MockTransactionRepoWithLinks repo;
    late TransactionsViewModel viewModel;

    setUp(() {
      repo = MockTransactionRepoWithLinks();
      viewModel = TransactionsViewModel(repository: repo);
    });

    test('allLinksForCategoryTree and hasLinkedPersons correctly aggregate parent and subcategory links', () async {
      final topCat = AppReason(id: 10, name: 'Food & Dining', isSystem: false);
      final subCat1 = AppReason(id: 11, name: 'Groceries', parentId: 10, isSystem: false);
      final subCat2 = AppReason(id: 12, name: 'Restaurants', parentId: 10, isSystem: false);
      final otherCat = AppReason(id: 20, name: 'Transportation', isSystem: false);

      final linkTop = AppReasonLink(id: 1, reasonId: 10, linkedName: 'Abebe Supermarket', linkType: 'receiver');
      final linkSub = AppReasonLink(id: 2, reasonId: 11, linkedName: 'Fresh Mart', linkType: 'receiver');

      repo.reasons = [topCat, subCat1, subCat2, otherCat];
      repo.reasonLinks = [linkTop, linkSub];

      await viewModel.loadReasons();

      // Top category tree has both links (direct top + child subcategory)
      final topLinks = viewModel.allLinksForCategoryTree(10);
      expect(topLinks.length, 2);
      expect(viewModel.hasLinkedPersons(10), isTrue);

      // Direct links for subcategory 11
      final sub11Links = viewModel.linksForReason(11);
      expect(sub11Links.length, 1);
      expect(sub11Links.first.linkedName, 'Fresh Mart');
      expect(viewModel.hasLinkedPersons(11), isTrue);

      // Subcategory 12 has no links
      expect(viewModel.linksForReason(12), isEmpty);
      expect(viewModel.hasLinkedPersons(12), isFalse);

      // Other category (20) has no links
      expect(viewModel.allLinksForCategoryTree(20), isEmpty);
      expect(viewModel.hasLinkedPersons(20), isFalse);
    });

    test('uniqueCounterparties extracts sorted unique names from senders and transactions', () async {
      repo.senders = [
        AppSender(senderName: 'Telebirr Service'),
        AppSender(senderName: 'Kebede Tadesse'),
      ];
      repo.transactions = [
        AppTransaction(
          id: 'tx_1',
          name: 'CBE',
          amount: 500,
          type: 'income',
          date: DateTime.now(),
          sender: 'Almaz Wolde',
          category: 'Transfer',
          rawMessage: 'msg',
          isAutoDetected: true,
        ),
        AppTransaction(
          id: 'tx_2',
          name: 'Telebirr',
          amount: 200,
          type: 'expense',
          date: DateTime.now(),
          sender: 'Kebede Tadesse',
          category: 'Transfer',
          rawMessage: 'msg',
          isAutoDetected: true,
        ),
      ];

      await viewModel.loadAll();

      final counterparties = viewModel.uniqueCounterparties;
      expect(counterparties.contains('Almaz Wolde'), isTrue);
      expect(counterparties.contains('Kebede Tadesse'), isTrue);
      expect(counterparties.contains('Telebirr Service'), isTrue);
      // Ensure no duplicates
      expect(counterparties.where((n) => n == 'Kebede Tadesse').length, 1);
    });

    test('Adding and removing reason links updates ViewModel state in real-time', () async {
      final reason = AppReason(id: 30, name: 'Utilities', isSystem: false);
      repo.reasons = [reason];
      await viewModel.loadReasons();

      expect(viewModel.hasLinkedPersons(30), isFalse);

      await viewModel.addReasonLinkScoped(
        reasonId: 30,
        linkedName: 'Ethiopian Electric Utility',
        linkType: 'receiver',
        scope: LinkScope.allTransactions,
      );

      expect(viewModel.hasLinkedPersons(30), isTrue);
      final links = viewModel.linksForReason(30);
      expect(links.length, 1);
      expect(links.first.linkedName, 'Ethiopian Electric Utility');

      await viewModel.deleteReasonLink(links.first.id!);
      expect(viewModel.hasLinkedPersons(30), isFalse);
    });
  });
}
