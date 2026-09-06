import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/loan_record.dart';
import '../../models/transaction.dart';
import '../../presentation/viewmodels/loans_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Bottom sheet allowing the user to select an existing transaction to attach
/// as a loan repayment.
///
/// Strictly lists outgoing transactions for borrowed loans (debts) and
/// incoming transactions for lent loans. Candidates are intelligently sorted
/// by amount and date proximity to the loan, with responsive filters for bank and date.
class SelectTransactionSheet extends StatefulWidget {
  final LoanRecord loan;

  const SelectTransactionSheet({
    super.key,
    required this.loan,
  });

  /// Static helper to show this sheet with blurred backdrop.
  static Future<AppTransaction?> show(
    BuildContext context, {
    required LoanRecord loan,
  }) {
    return AppDrawer.show<AppTransaction>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SelectTransactionSheet(loan: loan),
    );
  }

  @override
  State<SelectTransactionSheet> createState() => _SelectTransactionSheetState();
}

class _SelectTransactionSheetState extends State<SelectTransactionSheet> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedBank = 'All';
  AppDateFilterValue _dateFilter = const AppDateFilterValue.anyTime();
  bool _filterSinceLoan = false;
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Calculates a proximity ranking score where lower values indicate closer
  /// relevance (closer amount and closer date to the loan creation).
  double _calculateProximityScore({
    required AppTransaction tx,
    required double targetAmount,
    required DateTime targetDate,
    required double principalAmount,
  }) {
    final amountDiff = (tx.amount - targetAmount).abs();
    final relAmount = targetAmount > 0 ? (amountDiff / targetAmount) : amountDiff;

    final isExactRemaining = amountDiff < 0.01;
    final isExactPrincipal = (tx.amount - principalAmount).abs() < 0.01;

    // Exact matches receive a strong negative bonus to bubble to the very top
    final exactBonus = isExactRemaining
        ? -200.0
        : (isExactPrincipal ? -100.0 : 0.0);

    // Date difference in days from loan creation date
    final dayDiff = (tx.date.difference(targetDate).inSeconds / 86400.0).abs();

    // Penalty for transactions before loan was created
    final isBeforeLoan = tx.date.isBefore(targetDate);
    final beforePenalty = isBeforeLoan ? 2.5 : 0.0;

    // Weighted composite score: amount proximity is primary, date proximity is secondary
    return exactBonus + (relAmount * 3.5) + (dayDiff / 15.0) + beforePenalty;
  }

  @override
  Widget build(BuildContext context) {
    final loansVM = context.watch<LoansViewModel>();
    final isBorrowed = widget.loan.loanType == 'borrowed';

    // Strictly fetch matching direction: outgoing (expense) for borrowed loans,
    // incoming (income) for lent loans.
    final candidateList = loansVM.getEligibleTransactionsForLoan(
      widget.loan,
      allowAll: false,
    );

    // Extract all unique banks present in the eligible transactions
    final availableBanks = candidateList
        .map((tx) => tx.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final targetAmount = widget.loan.remainingAmount > 0
        ? widget.loan.remainingAmount
        : widget.loan.principalAmount;
    final targetDate = widget.loan.loanDate;
    final principalAmount = widget.loan.principalAmount;

    // Apply filtering: Bank, Date Preset/Range, Since-Loan, and Search query
    final filtered = candidateList.where((tx) {
      // 1. Bank filter
      if (_selectedBank != 'All' &&
          tx.name.trim().toLowerCase() != _selectedBank.toLowerCase()) {
        return false;
      }

      // 2. Date preset / range filter
      if (!_dateFilter.matches(tx.date)) {
        return false;
      }

      // 3. Since Loan quick filter
      if (_filterSinceLoan) {
        final loanDay = DateTime(
          widget.loan.loanDate.year,
          widget.loan.loanDate.month,
          widget.loan.loanDate.day,
        );
        if (tx.date.isBefore(loanDay)) {
          return false;
        }
      }

      // 4. Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final sender = tx.sender.toLowerCase();
        final name = tx.name.toLowerCase();
        final note = (tx.note ?? '').toLowerCase();
        final amountStr = tx.amount.toString();
        if (!sender.contains(query) &&
            !name.contains(query) &&
            !note.contains(query) &&
            !amountStr.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by proximity score: closest amount and closest date first
    filtered.sort((a, b) {
      final scoreA = _calculateProximityScore(
        tx: a,
        targetAmount: targetAmount,
        targetDate: targetDate,
        principalAmount: principalAmount,
      );
      final scoreB = _calculateProximityScore(
        tx: b,
        targetAmount: targetAmount,
        targetDate: targetDate,
        principalAmount: principalAmount,
      );
      final cmp = scoreA.compareTo(scoreB);
      if (cmp != 0) return cmp;

      // Tie-breaker: most recent date
      return b.date.compareTo(a.date);
    });

    final hasActiveFilters = _selectedBank != 'All' ||
        !_dateFilter.isDefault ||
        _filterSinceLoan ||
        _searchQuery.isNotEmpty;

    return AppDrawer(
      heightFactor: _isSearchExpanded ? 0.94 : 0.88,
      backgroundColor: AppColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row / Expandable Search Bar
          AppSearchBar(
            mode: AppSearchBarMode.pill,
            icon: Icons.receipt_long_rounded,
            title: 'Select Transaction',
            pillLabel: 'Search',
            isExpanded: _isSearchExpanded,
            controller: _searchCtrl,
            hint: 'Search by counterparty, bank, amount…',
            autofocus: true,
            height: 38,
            onExpandChanged: (expanded) {
              setState(() => _isSearchExpanded = expanded);
            },
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            onClear: () => setState(() => _searchQuery = ''),
            onClose: () {
              setState(() {
                _isSearchExpanded = false;
                _searchQuery = '';
              });
            },
            backgroundColor: AppColors.drawerCard,
            iconColor: Colors.white70,
            textColor: Colors.white,
            hintColor: AppColors.textSoft,
          ),
          const SizedBox(height: 12),

          // Filters Row: Date filter & Bank pills
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                // Date Filter Pill Menu
                AppDateFilter(
                  value: _dateFilter,
                  onChanged: (val) => setState(() => _dateFilter = val),
                  variant: AppDropdownVariant.dark,
                  height: 32,
                ),
                const SizedBox(width: 8),

                // Quick "Since Loan" Pill
                AppButton.pill(
                  text: 'Since Loan (${DateFormat('MMM d').format(widget.loan.loanDate)})',
                  isSelected: _filterSinceLoan,
                  height: 32,
                  onPressed: () => setState(() => _filterSinceLoan = !_filterSinceLoan),
                ),
                const SizedBox(width: 8),

                // All Banks Pill
                AppButton.pill(
                  text: 'All Banks',
                  isSelected: _selectedBank == 'All',
                  height: 32,
                  onPressed: () => setState(() => _selectedBank = 'All'),
                ),

                // Available Banks Pills
                for (final bank in availableBanks) ...[
                  const SizedBox(width: 8),
                  AppButton.pill(
                    text: bank,
                    isSelected: _selectedBank == bank,
                    height: 32,
                    onPressed: () => setState(() => _selectedBank = bank),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Transaction list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32.0,
                        horizontal: 24.0,
                      ),
                      child: AppEmptyState(
                        icon: hasActiveFilters
                            ? Icons.filter_alt_off_rounded
                            : Icons.receipt_outlined,
                        title: hasActiveFilters
                            ? 'No matching transactions'
                            : 'No available transactions',
                        subtitle: hasActiveFilters
                            ? 'Try adjusting your search terms or filter selections.'
                            : 'No unlinked ${isBorrowed ? 'outgoing' : 'incoming'} transactions found to attach.',
                        actionText: hasActiveFilters ? 'Clear Filters' : null,
                        onAction: hasActiveFilters
                            ? () {
                                setState(() {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                  _selectedBank = 'All';
                                  _dateFilter =
                                      const AppDateFilterValue.anyTime();
                                  _filterSinceLoan = false;
                                  _isSearchExpanded = false;
                                });
                              }
                            : null,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tx = filtered[index];
                      final isIncome = tx.type == 'income';

                      // Counterparty name displayed prominently
                      final counterparty = tx.sender.trim().isNotEmpty
                          ? tx.sender.trim()
                          : (tx.name.trim().isNotEmpty
                              ? tx.name.trim()
                              : 'Unknown Counterparty');
                      final bankName = tx.name.trim();
                      final dateStr =
                          DateFormat('MMM d, yyyy • h:mm a').format(tx.date);

                      // Match detection
                      final isExactRemaining =
                          (tx.amount - targetAmount).abs() < 0.01;
                      final isExactPrincipal =
                          (tx.amount - principalAmount).abs() < 0.01 &&
                              targetAmount != principalAmount;
                      final isCloseAmount = !isExactRemaining &&
                          !isExactPrincipal &&
                          targetAmount > 0 &&
                          (tx.amount - targetAmount).abs() / targetAmount <= 0.10;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(tx),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.modalCard,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                // Direction Icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isIncome
                                        ? AppColors.positive.withValues(alpha: 0.12)
                                        : AppColors.negative.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isIncome
                                        ? AppColors.positive
                                        : AppColors.negative,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Details Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        counterparty,
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          if (bankName.isNotEmpty) ...[
                                            Text(
                                              bankName,
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '•',
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textSoft,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: Text(
                                              dateStr,
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Match Indicator Pills
                                      if (isExactRemaining) ...[
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.positive
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.check_circle_outline_rounded,
                                                size: 11,
                                                color: AppColors.positive,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Exact Match',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: AppColors.positive,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else if (isExactPrincipal) ...[
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.info
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            'Full Principal',
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.info,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ] else if (isCloseAmount) ...[
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            'Close Amount',
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Amount Display
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${isIncome ? '+' : '-'}${NumberFormat('#,##0.00').format(tx.amount)}',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: isIncome
                                                ? AppColors.positive
                                                : Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        CurrencySymbolWidget(
                                          size: 11,
                                          color: isIncome
                                              ? AppColors.positive
                                              : AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
