import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';

class MockPersistenceTransactionRepo implements TransactionRepository {
  List<AppSender> senders = [];
  List<AppTransaction> transactions = [];
  List<AppReason> reasons = [];
  List<AppReasonLink> reasonLinks = [];
  Set<String> pausedBanks = {};
  final Map<String, String> tombstones = {};

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
  Future<int> insertReason(AppReason reason) async {
    final newId = (reasons.isEmpty ? 0 : reasons.map((r) => r.id ?? 0).reduce((a, b) => a > b ? a : b)) + 1;
    final created = AppReason(
      id: newId,
      name: reason.name,
      parentId: reason.parentId,
      isSystem: reason.isSystem,
      isSpecial: reason.isSpecial,
      icon: reason.icon,
      color: reason.color,
    );
    reasons.add(created);

    // Remove matching tombstone
    final key = '${reason.name.toLowerCase().trim()}::${reason.parentId ?? ''}';
    tombstones.remove(key);

    return newId;
  }

  @override
  Future<int> updateReason(AppReason reason) async {
    final idx = reasons.indexWhere((r) => r.id == reason.id);
    if (idx != -1) {
      reasons[idx] = reason;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteReason(int id) async {
    final target = reasons.where((r) => r.id == id).firstOrNull;
    if (target != null) {
      final key = '${target.name.toLowerCase().trim()}::${target.parentId ?? ''}';
      tombstones[key] = DateTime.now().toIso8601String();
    }
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

  group('Category Persistence & Hierarchy Tests', () {
    late MockPersistenceTransactionRepo repo;
    late TransactionsViewModel viewModel;

    setUp(() {
      repo = MockPersistenceTransactionRepo();
      viewModel = TransactionsViewModel(repository: repo);
    });

    test('addReason preserves parentId, isSystem, isSpecial in memory', () async {
      final parent = AppReason(id: 1, name: 'Food', isSystem: true);
      repo.reasons = [parent];
      await viewModel.loadReasons();

      // Add a subcategory using addReason
      final sub = AppReason(
        name: 'Pastries',
        parentId: 1,
        isSystem: false,
        isSpecial: false,
      );

      await viewModel.addReason(sub);

      expect(viewModel.reasons.length, 2);
      final addedSub = viewModel.reasons.firstWhere((r) => r.name == 'Pastries');
      expect(addedSub.parentId, 1);
      expect(addedSub.isSubcategory, isTrue);
      expect(addedSub.isTopLevelCategory, isFalse);

      final subsForFood = viewModel.subcategoriesFor(1);
      expect(subsForFood.length, 1);
      expect(subsForFood.first.name, 'Pastries');
    });

    test('deleteReason removes category and cascades child subcategories in memory and marks tombstone', () async {
      final topCat = AppReason(id: 10, name: 'Custom Project', isSystem: false);
      final subCat1 = AppReason(id: 11, name: 'Phase 1', parentId: 10, isSystem: false);
      final subCat2 = AppReason(id: 12, name: 'Phase 2', parentId: 10, isSystem: false);
      final otherCat = AppReason(id: 20, name: 'Transportation', isSystem: true);

      repo.reasons = [topCat, subCat1, subCat2, otherCat];
      await viewModel.loadReasons();

      expect(viewModel.reasons.length, 4);

      // Delete parent category
      await viewModel.deleteReason(10);

      // Parent and children are removed
      expect(viewModel.reasons.length, 1);
      expect(viewModel.reasons.first.name, 'Transportation');
      expect(repo.tombstones.containsKey('custom project::'), isTrue);
    });

    test('addTopLevelCategory creates valid top level category', () async {
      await viewModel.addTopLevelCategory('Custom Category');

      expect(viewModel.topLevelCategories.length, 1);
      expect(viewModel.topLevelCategories.first.name, 'Custom Category');
      expect(viewModel.topLevelCategories.first.isTopLevelCategory, isTrue);
      expect(viewModel.topLevelCategories.first.isSubcategory, isFalse);
    });

    test('addSubcategory creates valid subcategory linked to parent', () async {
      final cat = await viewModel.addTopLevelCategory('Shopping');
      final sub = await viewModel.addSubcategory(cat.id!, 'Groceries');

      expect(sub.parentId, cat.id);
      expect(sub.isSubcategory, isTrue);

      final subs = viewModel.subcategoriesFor(cat.id!);
      expect(subs.length, 1);
      expect(subs.first.name, 'Groceries');
    });
  });
}
