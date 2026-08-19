import '../../../models/transaction.dart';
import '../../../widgets/app_date_filter.dart';

class FilterTransactionsParams {
  final String? bankFilter; // Matches tx.name
  final String? senderFilter; // Matches tx.sender
  final String? typeFilter; // 'All', 'Income', 'Expense', 'Incoming', 'Outgoing', 'Bookmarked'
  final String? searchQuery;
  final AppDateFilterValue? dateFilter;
  final bool onlyUncategorized;
  final bool onlyBookmarked;
  final String? sortBy; // 'Date: Newest', 'Date: Oldest', 'Amount: High-Low', 'Amount: Low-High', 'Name: A-Z', 'Name: Z-A'

  const FilterTransactionsParams({
    this.bankFilter,
    this.senderFilter,
    this.typeFilter,
    this.searchQuery,
    this.dateFilter,
    this.onlyUncategorized = false,
    this.onlyBookmarked = false,
    this.sortBy,
  });
}

class FilterTransactionsUseCase {
  const FilterTransactionsUseCase();

  List<AppTransaction> execute({
    required List<AppTransaction> transactions,
    required FilterTransactionsParams params,
  }) {
    final filtered = transactions.where((tx) {
      // 0. Bookmarked Only Filter
      if (params.onlyBookmarked && !tx.isBookmarked) {
        return false;
      }

      // 1. Type Filter
      if (params.typeFilter != null &&
          params.typeFilter != 'All' &&
          params.typeFilter!.isNotEmpty) {
        final t = params.typeFilter!.toLowerCase();
        if ((t == 'bookmarked' || t == 'favorites' || t == 'starred') && !tx.isBookmarked) {
          return false;
        } else if ((t == 'income' || t == 'incoming') && tx.type != 'income') {
          return false;
        } else if ((t == 'expense' || t == 'outgoing') && tx.type != 'expense') {
          return false;
        }
      }

      // 2. Bank Filter (tx.name)
      if (params.bankFilter != null &&
          params.bankFilter != 'All Banks' &&
          params.bankFilter != 'All' &&
          params.bankFilter!.isNotEmpty) {
        if (tx.name.toUpperCase() != params.bankFilter!.toUpperCase()) {
          return false;
        }
      }

      // 3. Sender / Counterparty Filter (tx.sender)
      if (params.senderFilter != null &&
          params.senderFilter != 'All Senders' &&
          params.senderFilter != 'All' &&
          params.senderFilter!.isNotEmpty) {
        final sf = params.senderFilter!.trim().toUpperCase();
        final txs = tx.sender.trim().toUpperCase();
        if (txs != sf && !txs.contains(sf) && !sf.contains(txs)) {
          return false;
        }
      }

      // 4. Date Filter
      if (params.dateFilter != null) {
        if (!params.dateFilter!.matches(tx.date)) {
          return false;
        }
      }

      // 5. Uncategorized Only Filter
      if (params.onlyUncategorized ||
          (params.searchQuery != null &&
              params.searchQuery!.toLowerCase().trim() == 'uncategorized')) {
        final isUncat = tx.resolvedReason == null || tx.resolvedReason!.isEmpty;
        if (!isUncat) return false;
      }

      // 6. Search Query
      if (params.searchQuery != null &&
          params.searchQuery!.trim().isNotEmpty &&
          params.searchQuery!.toLowerCase().trim() != 'uncategorized') {
        final query = params.searchQuery!.toLowerCase().trim();
        final matches = tx.sender.toLowerCase().contains(query) ||
            tx.name.toLowerCase().contains(query) ||
            (tx.reason?.toLowerCase().contains(query) ?? false) ||
            (tx.customReasonText?.toLowerCase().contains(query) ?? false) ||
            (tx.resolvedReason?.toLowerCase().contains(query) ?? false);
        if (!matches) return false;
      }

      return true;
    }).toList();

    // 7. Apply Sorting
    final sort = params.sortBy?.toLowerCase().trim() ?? 'date: newest';
    if (sort.contains('date: oldest') || sort.contains('oldest') || sort == 'date_asc') {
      filtered.sort((a, b) => a.date.compareTo(b.date));
    } else if (sort.contains('high-low') || sort.contains('amount: high') || sort.contains('highest') || sort == 'amount_desc') {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (sort.contains('low-high') || sort.contains('amount: low') || sort.contains('lowest') || sort == 'amount_asc') {
      filtered.sort((a, b) => a.amount.compareTo(b.amount));
    } else if (sort.contains('a-z') || sort.contains('name: a-z') || sort == 'name_asc') {
      filtered.sort((a, b) => a.sender.toLowerCase().compareTo(b.sender.toLowerCase()));
    } else if (sort.contains('z-a') || sort.contains('name: z-a') || sort == 'name_desc') {
      filtered.sort((a, b) => b.sender.toLowerCase().compareTo(a.sender.toLowerCase()));
    } else {
      // Default: Date Newest First
      filtered.sort((a, b) => b.date.compareTo(a.date));
    }

    return filtered;
  }
}
