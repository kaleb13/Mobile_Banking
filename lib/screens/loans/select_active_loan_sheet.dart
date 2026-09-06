import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/loan_record.dart';
import '../../models/transaction.dart';
import '../../presentation/viewmodels/loans_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Bottom sheet allowing the user to select an active loan to apply a transaction
/// to as a repayment.
class SelectActiveLoanSheet extends StatefulWidget {
  final AppTransaction transaction;

  const SelectActiveLoanSheet({
    super.key,
    required this.transaction,
  });

  /// Static helper to show this sheet.
  static Future<LoanRecord?> show(
    BuildContext context, {
    required AppTransaction transaction,
  }) {
    return AppDrawer.show<LoanRecord>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SelectActiveLoanSheet(transaction: transaction),
    );
  }

  @override
  State<SelectActiveLoanSheet> createState() => _SelectActiveLoanSheetState();
}

class _SelectActiveLoanSheetState extends State<SelectActiveLoanSheet> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loansVM = context.watch<LoansViewModel>();
    final isIncome = widget.transaction.type == 'income';
    final expectedLoanType = isIncome ? 'lent' : 'borrowed';

    // Prioritize active loans matching transaction flow
    final allActive = loansVM.activeLoans;
    final matchingActive = allActive
        .where((l) => l.loanType == expectedLoanType)
        .toList();
    final loansToDisplay = matchingActive.isNotEmpty ? matchingActive : allActive;

    final filtered = loansToDisplay.where((l) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return l.personName.toLowerCase().contains(q) ||
          (l.note ?? '').toLowerCase().contains(q) ||
          (l.contractNumber ?? '').toLowerCase().contains(q);
    }).toList();

    return AppDrawer(
      heightFactor: _isSearchExpanded ? 0.94 : 0.85,
      backgroundColor: AppColors.surfaceElevated,
      child: Column(
        children: [
          // Header Row / Expandable Search Bar
          AppSearchBar(
            mode: AppSearchBarMode.pill,
            icon: Icons.handshake_outlined,
            title: 'Select Active Loan',
            pillLabel: 'Search',
            isExpanded: _isSearchExpanded,
            controller: _searchCtrl,
            hint: 'Search by borrower or lender name…',
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
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: AppEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: _searchQuery.isEmpty
                            ? 'No active loans'
                            : 'No matching loans',
                        subtitle: _searchQuery.isEmpty
                            ? 'There are no active loans to repay.'
                            : 'Try adjusting your search terms.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final loan = filtered[index];
                      final isLent = loan.loanType == 'lent';
                      final accentColor =
                          isLent ? AppColors.positive : AppColors.warning;
                      final remaining = loan.remainingAmount;
                      final progress = loan.progressPercent;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(loan),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isLent
                                            ? Icons.arrow_outward_rounded
                                            : Icons.arrow_downward_rounded,
                                        color: accentColor,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loan.personName,
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isLent
                                                ? 'Owes you (Lent)'
                                                : 'You owe (Borrowed)',
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              NumberFormat('#,##0.00')
                                                  .format(remaining),
                                              style: AppTypography.bodyMedium.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const CurrencySymbolWidget(
                                              size: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'remaining',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textSoft,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 5,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.08),
                                    valueColor:
                                        AlwaysStoppedAnimation(accentColor),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Due: ${DateFormat('MMM d, yyyy').format(loan.dueDate)}',
                                      style: AppTypography.caption.copyWith(
                                        color: loan.isOverdue
                                            ? AppColors.negative
                                            : AppColors.textSecondary,
                                        fontWeight: loan.isOverdue
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}% paid',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
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
