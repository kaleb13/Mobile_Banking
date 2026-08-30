import '../../models/transaction.dart';
import '../../models/transaction_split.dart';
import '../../models/app_notification.dart';
import '../../models/reason.dart';
import '../../models/sender.dart';
import '../../models/transaction_attachment.dart';
import '../../services/database_service.dart';
import '../../services/sms_batch_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract Interface — Full Transaction Domain Data Access
// ─────────────────────────────────────────────────────────────────────────────

abstract class TransactionRepository {
  // ── Transactions ──
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset});
  Future<List<AppTransaction>> getTransactionsSince(DateTime since, {int? limit, int? offset});
  Future<int> insertTransaction(AppTransaction transaction);
  Future<int> insertTransactionsBatch(List<AppTransaction> transactions);
  Future<int> updateTransaction(AppTransaction transaction);
  Future<int> deleteTransaction(String id);
  Future<void> deleteAllTransactions();
  Future<int> deleteTransactionsOlderThan(DateTime cutoff);
  Future<int> deleteUncategorizedTransactionsForBank(String bankName);
  Future<DateTime?> getLastTransactionDate();
  Future<int> getTransactionCount();
  Future<void> checkpointWal();

  // ── Transaction Splits ──
  Future<List<TransactionSplit>> getAllTransactionSplits();
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId);
  Future<void> saveTransactionSplits(String transactionId, List<TransactionSplit> splits);
  Future<int> deleteTransactionSplits(String transactionId);

  // ── Transaction Reason Updates ──
  Future<int> reconcilePendingNotificationReasons();
  Future<int> updateTransactionReason(
      String id, String reason, int? reasonId);
  Future<int> updateTransactionReasonByRawMessage(
      String rawMessage, String reason, int? reasonId);
  Future<int> unlinkSingleTransaction(String id);
  Future<int> unlinkAllTransactionsForContact({
    required String contactName,
    int? reasonId,
  });

  // ── Bookmarks & Notes ──
  Future<int> setTransactionBookmarked(String id, bool isBookmarked);

  // ── Attachments ──
  Future<int> insertAttachment(TransactionAttachment attachment);
  Future<List<TransactionAttachment>> getAttachmentsForTransaction(String transactionId);
  Future<int> deleteAttachment(String attachmentId);

  // ── Senders ──
  Future<List<AppSender>> getSenders();
  Future<int> insertSender(AppSender sender);
  Future<int> updateSender(AppSender sender);
  Future<int> deleteSender(String id);

  // ── Reasons ──
  Future<List<AppReason>> getReasons();
  Future<AppReason?> getReasonById(int id);
  Future<int> insertReason(AppReason reason);
  Future<int> updateReason(AppReason reason);
  Future<int> deleteReason(int id);
  Future<List<AppReasonLink>> getReasonLinks();
  Future<List<AppReasonLink>> getLinksForReason(int reasonId);
  Future<int> insertReasonLink(AppReasonLink link);
  Future<int> deleteReasonLink(int id);
  Future<void> deleteAllUserReasons();
  Future<AppReason?> findAutoReason(
      String senderName, String transactionType);

  // ── Auto-Reason Rules ──
  Future<List<AutoReasonRule>> getAutoReasonRules();

  // ── Distinct Queries ──
  Future<List<String>> getDistinctBankNames();
  Future<List<String>> getDistinctSenders();

  // ── Notifications (legacy — will move to NotificationRepository) ──
  Future<List<AppNotification>> getNotifications();
  Future<void> insertNotification(AppNotification notification);
  Future<void> deleteAllNotifications();
  Future<int> deleteUncategorizedNotificationsForBank(String bankName);

  // ── Paused Banks ──
  Future<Set<String>> getPausedBanks();
  Future<void> setPausedBanks(Set<String> banks);
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete SQLite Implementation
// ─────────────────────────────────────────────────────────────────────────────

class TransactionRepositoryImpl implements TransactionRepository {
  final DatabaseService _db;

  TransactionRepositoryImpl({DatabaseService? dbService})
      : _db = dbService ?? DatabaseService.instance;

  // ── Transactions ──────────────────────────────────────────────────────────

  @override
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) =>
      _db.getTransactions(limit: limit, offset: offset);

  @override
  Future<List<AppTransaction>> getTransactionsSince(DateTime since, {int? limit, int? offset}) =>
      _db.getTransactionsSince(since, limit: limit, offset: offset);

  @override
  Future<int> insertTransaction(AppTransaction transaction) =>
      _db.insertTransaction(transaction);

  @override
  Future<int> insertTransactionsBatch(List<AppTransaction> transactions) =>
      _db.insertTransactionsBatch(transactions);

  @override
  Future<int> updateTransaction(AppTransaction transaction) =>
      _db.updateTransaction(transaction);

  @override
  Future<int> deleteTransaction(String id) => _db.deleteTransaction(id);

  @override
  Future<void> deleteAllTransactions() => _db.deleteAllTransactions();

  @override
  Future<int> deleteTransactionsOlderThan(DateTime cutoff) =>
      _db.deleteTransactionsOlderThan(cutoff);

  @override
  Future<int> deleteUncategorizedTransactionsForBank(String bankName) =>
      _db.deleteUncategorizedTransactionsForBank(bankName);

  @override
  Future<DateTime?> getLastTransactionDate() => _db.getLastTransactionDate();

  @override
  Future<void> checkpointWal() => _db.checkpointWal();

  @override
  Future<int> getTransactionCount() => _db.getTransactionCount();

  // ── Transaction Splits ────────────────────────────────────────────────────

  @override
  Future<List<TransactionSplit>> getAllTransactionSplits() =>
      _db.getAllTransactionSplits();

  @override
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId) =>
      _db.getSplitsForTransaction(transactionId);

  @override
  Future<void> saveTransactionSplits(
          String transactionId, List<TransactionSplit> splits) =>
      _db.saveTransactionSplits(transactionId, splits);

  @override
  Future<int> deleteTransactionSplits(String transactionId) =>
      _db.deleteTransactionSplits(transactionId);

  // ── Transaction Reason Updates ────────────────────────────────────────────

  @override
  Future<int> reconcilePendingNotificationReasons() =>
      _db.reconcilePendingNotificationReasons();

  @override
  Future<int> updateTransactionReason(
    String id, String reason, int? reasonId,
  ) =>
      _db.updateTransactionReason(id, reason, reasonId);

  @override
  Future<int> updateTransactionReasonByRawMessage(
    String rawMessage, String reason, int? reasonId,
  ) =>
      _db.updateTransactionReasonByRawMessage(rawMessage, reason, reasonId);

  @override
  Future<int> unlinkSingleTransaction(String id) =>
      _db.unlinkSingleTransaction(id);

  @override
  Future<int> unlinkAllTransactionsForContact({
    required String contactName,
    int? reasonId,
  }) =>
      _db.unlinkAllTransactionsForContact(
        contactName: contactName,
        reasonId: reasonId,
      );

  // ── Bookmarks & Notes ─────────────────────────────────────────────────────

  @override
  Future<int> setTransactionBookmarked(String id, bool isBookmarked) =>
      _db.setTransactionBookmarked(id, isBookmarked);

  // ── Attachments ───────────────────────────────────────────────────────────

  @override
  Future<int> insertAttachment(TransactionAttachment attachment) =>
      _db.insertAttachment(attachment);

  @override
  Future<List<TransactionAttachment>> getAttachmentsForTransaction(String transactionId) =>
      _db.getAttachmentsForTransaction(transactionId);

  @override
  Future<int> deleteAttachment(String attachmentId) =>
      _db.deleteAttachment(attachmentId);

  // ── Senders ───────────────────────────────────────────────────────────────

  @override
  Future<List<AppSender>> getSenders() => _db.getSenders();

  @override
  Future<int> insertSender(AppSender sender) => _db.insertSender(sender);

  @override
  Future<int> updateSender(AppSender sender) => _db.updateSender(sender);

  @override
  Future<int> deleteSender(String id) => _db.deleteSender(id);

  // ── Reasons ───────────────────────────────────────────────────────────────

  @override
  Future<List<AppReason>> getReasons() => _db.getReasons();

  @override
  Future<AppReason?> getReasonById(int id) => _db.getReasonById(id);

  @override
  Future<int> insertReason(AppReason reason) => _db.insertReason(reason);

  @override
  Future<int> updateReason(AppReason reason) => _db.updateReason(reason);

  @override
  Future<int> deleteReason(int id) => _db.deleteReason(id);

  @override
  Future<List<AppReasonLink>> getReasonLinks() => _db.getReasonLinks();

  @override
  Future<List<AppReasonLink>> getLinksForReason(int reasonId) =>
      _db.getLinksForReason(reasonId);

  @override
  Future<int> insertReasonLink(AppReasonLink link) =>
      _db.insertReasonLink(link);

  @override
  Future<int> deleteReasonLink(int id) => _db.deleteReasonLink(id);

  @override
  Future<void> deleteAllUserReasons() => _db.deleteAllUserReasons();

  @override
  Future<AppReason?> findAutoReason(
      String senderName, String transactionType) =>
      _db.findAutoReason(senderName, transactionType);

  @override
  Future<List<AutoReasonRule>> getAutoReasonRules() =>
      _db.getAutoReasonRules();

  // ── Distinct Queries ──────────────────────────────────────────────────────

  @override
  Future<List<String>> getDistinctBankNames() => _db.getDistinctBankNames();

  @override
  Future<List<String>> getDistinctSenders() => _db.getDistinctSenders();

  // ── Notifications (legacy) ────────────────────────────────────────────────

  @override
  Future<List<AppNotification>> getNotifications() => _db.getNotifications();

  @override
  Future<void> insertNotification(AppNotification notification) =>
      _db.insertNotification(notification);

  @override
  Future<void> deleteAllNotifications() => _db.deleteAllNotifications();

  @override
  Future<int> deleteUncategorizedNotificationsForBank(String bankName) =>
      _db.deleteUncategorizedNotificationsForBank(bankName);

  // ── Paused Banks ──────────────────────────────────────────────────────────

  @override
  Future<Set<String>> getPausedBanks() => _db.getPausedBanks();

  @override
  Future<void> setPausedBanks(Set<String> banks) => _db.setPausedBanks(banks);
}
