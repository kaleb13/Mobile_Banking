import '../../../models/transaction.dart';
import '../../../widgets/app_date_filter.dart';
import '../../../utils/counterparty_matcher.dart';

class FilterTransactionsParams {
  final String? bankFilter; // Matches tx.bankName
  final String? counterpartyFilter; // Matches tx.counterparty
  final String? senderFilter; // Backward-compatible alias for counterpartyFilter
  final String? categoryFilter; // Matches tx.resolvedCategory / tx.resolvedReason
  final String? typeFilter; // 'All', 'Income', 'Expense', 'Incoming', 'Outgoing', 'Bookmarked'
  final int? simSlotFilter; // null = All SIMs, 0 = SIM 1, 1 = SIM 2
  final String? searchQuery;
  final AppDateFilterValue? dateFilter;
  final bool onlyUncategorized;
  final bool onlyBookmarked;
  final String? sortBy; // 'Date: Newest', 'Date: Oldest', 'Amount: High-Low', 'Amount: Low-High', 'Name: A-Z', 'Name: Z-A'
  final int? limit;

  const FilterTransactionsParams({
    this.bankFilter,
    String? counterpartyFilter,
    String? senderFilter,
    this.categoryFilter,
    this.typeFilter,
    this.simSlotFilter,
    this.searchQuery,
    this.dateFilter,
    this.onlyUncategorized = false,
    this.onlyBookmarked = false,
    this.sortBy,
    this.limit,
  })  : counterpartyFilter = counterpartyFilter ?? senderFilter,
        senderFilter = counterpartyFilter ?? senderFilter;
}

class FilterTransactionsUseCase {
  const FilterTransactionsUseCase();

  List<AppTransaction> execute({
    required List<AppTransaction> transactions,
    required FilterTransactionsParams params,
  }) {
    if (transactions.isEmpty) return const [];

    final String? bankFilterUpper = (params.bankFilter != null &&
            params.bankFilter != 'All Banks' &&
            params.bankFilter != 'All' &&
            params.bankFilter!.isNotEmpty)
        ? params.bankFilter!.toUpperCase()
        : null;

    final String? counterpartyFilter = (params.counterpartyFilter != null &&
            params.counterpartyFilter != 'All Counterparties' &&
            params.counterpartyFilter != 'All Senders' &&
            params.counterpartyFilter != 'All' &&
            params.counterpartyFilter!.isNotEmpty)
        ? params.counterpartyFilter!
        : null;

    final String? categoryFilterLower = (params.categoryFilter != null &&
            params.categoryFilter != 'All' &&
            params.categoryFilter!.isNotEmpty)
        ? params.categoryFilter!.trim().toLowerCase()
        : null;

    final String? typeFilterLower = (params.typeFilter != null &&
            params.typeFilter != 'All' &&
            params.typeFilter!.isNotEmpty)
        ? params.typeFilter!.toLowerCase()
        : null;

    final String? searchLower = (params.searchQuery != null &&
            params.searchQuery!.trim().isNotEmpty &&
            params.searchQuery!.toLowerCase().trim() != 'uncategorized')
        ? params.searchQuery!.toLowerCase().trim()
        : null;

    final bool searchUncategorized = params.onlyUncategorized ||
        (params.searchQuery != null &&
            params.searchQuery!.toLowerCase().trim() == 'uncategorized');

    final List<AppTransaction> filtered = [];

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];

      // 0. Bookmarked Only Filter
      if (params.onlyBookmarked && !tx.isBookmarked) {
        continue;
      }

      // SIM Slot Filter
      if (params.simSlotFilter != null && tx.simSlot != params.simSlotFilter) {
        continue;
      }

      // 1. Type Filter
      if (typeFilterLower != null) {
        if ((typeFilterLower == 'bookmarked' ||
                typeFilterLower == 'favorites' ||
                typeFilterLower == 'starred') &&
            !tx.isBookmarked) {
          continue;
        } else if ((typeFilterLower == 'income' ||
                typeFilterLower == 'incoming') &&
            tx.type != 'income') {
          continue;
        } else if ((typeFilterLower == 'expense' ||
                typeFilterLower == 'outgoing') &&
            tx.type != 'expense') {
          continue;
        }
      }

      // 2. Bank Filter (tx.bankName)
      if (bankFilterUpper != null &&
          tx.bankName.toUpperCase() != bankFilterUpper) {
        continue;
      }

      // 3. Counterparty Filter (tx.counterparty)
      if (counterpartyFilter != null &&
          !CounterpartyMatcher.matches(tx.counterparty, counterpartyFilter)) {
        continue;
      }

      // 3.5 Category / Reason Filter
      if (categoryFilterLower != null) {
        final txReason =
            (tx.resolvedReason ?? '').trim().toLowerCase();
        final isMatch = (txReason.isNotEmpty &&
                (txReason == categoryFilterLower ||
                    txReason.contains(categoryFilterLower) ||
                    categoryFilterLower.contains(txReason))) ||
            (tx.reason?.toLowerCase().contains(categoryFilterLower) ?? false) ||
            (tx.customReasonText?.toLowerCase().contains(categoryFilterLower) ??
                false);
        if (!isMatch) {
          continue;
        }
      }

      // 4. Date Filter
      if (params.dateFilter != null) {
        if (!params.dateFilter!.matches(tx.date)) {
          continue;
        }
      }

      // 5. Uncategorized Only Filter
      if (searchUncategorized) {
        final isUncat =
            tx.resolvedReason == null || tx.resolvedReason!.isEmpty;
        if (!isUncat) continue;
      }

      // 6. Search Query
      if (searchLower != null) {
        final matches = tx.counterparty.toLowerCase().contains(searchLower) ||
            tx.bankName.toLowerCase().contains(searchLower) ||
            (tx.reason?.toLowerCase().contains(searchLower) ?? false) ||
            (tx.customReasonText?.toLowerCase().contains(searchLower) ??
                false) ||
            (tx.resolvedReason?.toLowerCase().contains(searchLower) ??
                false);
        if (!matches) continue;
      }

      filtered.add(tx);
    }

    // 7. Apply Sorting
    final sort = params.sortBy?.toLowerCase().trim() ?? 'date: newest';
    if (sort.contains('date: oldest') ||
        sort.contains('oldest') ||
        sort == 'date_asc') {
      filtered.sort((a, b) => a.date.compareTo(b.date));
    } else if (sort.contains('high-low') ||
        sort.contains('amount: high') ||
        sort.contains('highest') ||
        sort == 'amount_desc') {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (sort.contains('low-high') ||
        sort.contains('amount: low') ||
        sort.contains('lowest') ||
        sort == 'amount_asc') {
      filtered.sort((a, b) => a.amount.compareTo(b.amount));
    } else if (sort.contains('a-z') ||
        sort.contains('name: a-z') ||
        sort == 'name_asc') {
      filtered.sort(
          (a, b) => a.counterparty.toLowerCase().compareTo(b.counterparty.toLowerCase()));
    } else if (sort.contains('z-a') ||
        sort.contains('name: z-a') ||
        sort == 'name_desc') {
      filtered.sort(
          (a, b) => b.counterparty.toLowerCase().compareTo(a.counterparty.toLowerCase()));
    } else {
      // Default: Date Newest First
      filtered.sort((a, b) => b.date.compareTo(a.date));
    }

    if (params.limit != null && filtered.length > params.limit!) {
      return filtered.take(params.limit!).toList();
    }

    return filtered;
  }
}
