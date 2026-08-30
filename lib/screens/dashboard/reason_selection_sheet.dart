import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reason_transactions_screen.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ReasonSelectionSheet extends StatefulWidget {
  final AppReason? initialReason;
  final String? transactionType;
  final bool isCashSpending;
  final bool isSplitSelection;
  final Function(AppReason) onReasonSelected;

  const ReasonSelectionSheet({
    super.key,
    this.initialReason,
    this.transactionType,
    this.isCashSpending = false,
    this.isSplitSelection = false,
    required this.onReasonSelected,
  });

  /// Static helper to display this selection sheet using [AppBottomSheet].
  static Future<void> show(
    BuildContext context, {
    AppReason? initialReason,
    String? transactionType,
    bool isCashSpending = false,
    bool isSplitSelection = false,
    required Function(AppReason) onReasonSelected,
  }) {
    return AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReasonSelectionSheet(
        initialReason: initialReason,
        transactionType: transactionType,
        isCashSpending: isCashSpending,
        isSplitSelection: isSplitSelection,
        onReasonSelected: onReasonSelected,
      ),
    );
  }

  @override
  State<ReasonSelectionSheet> createState() => _ReasonSelectionSheetState();
}

class _ReasonSelectionSheetState extends State<ReasonSelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  int? _expandedCategoryId;
  AppReason? _selectedReason;

  static const Map<String, String> _specialReasonDescriptions = {
    'loan': 'Track loans, credit lines & debt repayments',
    'internal transfer': 'Transfer money between your accounts',
    'cash': 'Cash wallet & manual cash expenses',
    'pass-through': "Pass-through money that doesn't belong to you",
    'pass through': "Pass-through money that doesn't belong to you",
    'bounce': "Pass-through money that doesn't belong to you",
  };

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.initialReason;
  }

  bool _isSpecial(AppReason r) {
    if (r.isSpecial) return true;
    final nameLower = r.name.trim().toLowerCase();
    return _specialReasonDescriptions.containsKey(nameLower);
  }

  String _getSpecialDescription(String name) {
    final lower = name.trim().toLowerCase();
    return _specialReasonDescriptions[lower] ?? 'Special System Reason';
  }

  bool _isSelected(AppReason r) {
    if (_selectedReason == null) return false;
    if (_selectedReason!.id != null && r.id != null) {
      return _selectedReason!.id == r.id;
    }
    return _selectedReason!.name.trim().toLowerCase() == r.name.trim().toLowerCase();
  }

  void _showAddCategoryDialog(BuildContext context, TransactionsViewModel txVM,
      {AppReason? parentCategory}) {
    final ctrl = TextEditingController();
    final isSubcategory = parentCategory != null;

    AppModalDialog.show(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        return StatefulBuilder(builder: (ctx, setInner) {
          return AppModalDialog(
            title: isSubcategory ? 'New Subcategory' : 'New Category',
            subtitle:
                parentCategory != null ? 'Parent: ${parentCategory.name}' : null,
            confirmText: 'Save',
            cancelText: 'Cancel',
            onConfirm: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;

              AppReason newReason;
              if (parentCategory != null) {
                newReason =
                    await txVM.addSubcategory(parentCategory.id!, name);
              } else {
                newReason = await txVM.addTopLevelCategory(name);
              }

              if (mounted) {
                setState(() {
                  _selectedReason = newReason;
                  if (parentCategory != null) {
                    _expandedCategoryId = parentCategory.id;
                  }
                });
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField.modal(
                  controller: ctrl,
                  maxLength: 40,
                  autofocus: true,
                  hint: isSubcategory
                      ? 'Subcategory name...'
                      : 'Category name...',
                  borderRadius: BorderRadius.circular(16),
                  onChanged: (_) {
                    if (errorMsg != null) setInner(() => errorMsg = null);
                  },
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!,
                      style: const TextStyle(
                          color: AppColors.negative, fontSize: 12)),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  bool _isScrolledToTop = false;

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context);
    final query = _searchQuery.trim().toLowerCase();
    final bool isIncome = widget.transactionType?.toLowerCase() == 'income' ||
        widget.transactionType?.toLowerCase() == 'addition';

    final specialReasonsMap = <String, AppReason>{};
    for (var r in txVM.reasons.where(_isSpecial)) {
      final nameKey = r.name.trim().toLowerCase();
      // For split reason allocations: exclude Internal Transfer and Pass-Through
      if (widget.isSplitSelection &&
          (nameKey == 'internal transfer' ||
              nameKey == 'pass-through' ||
              nameKey == 'pass through' ||
              nameKey == 'bounce')) {
        continue;
      }
      // For cash spending/deductions: ONLY 'Loan' is permitted from special reasons.
      if (widget.isCashSpending && nameKey != 'loan') {
        continue;
      }
      // "Cash" reason is ONLY for withdrawals/expenses. In deposits/income, hide "Cash".
      if (isIncome && nameKey == 'cash') {
        continue;
      }
      if (nameKey.contains(query)) {
        specialReasonsMap.putIfAbsent(nameKey, () => r);
      }
    }
    final specialReasons = specialReasonsMap.values.toList();

    final topCategoriesMap = <String, AppReason>{};
    for (var r in txVM.topLevelCategories) {
      if (_isSpecial(r)) continue;
      final nameKey = r.name.trim().toLowerCase();
      final matchesName = nameKey.contains(query);
      final matchesSub = txVM.subcategoriesFor(r.id!).any((sub) => sub.name.toLowerCase().contains(query));
      if (matchesName || matchesSub) {
        topCategoriesMap.putIfAbsent(nameKey, () => r);
      }
    }
    final topCategories = topCategoriesMap.values.toList();

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final systemNavBottom = MediaQuery.paddingOf(context).bottom;
    final double extraBottom = bottomInset > 0 ? bottomInset : systemNavBottom;

    final targetHeight = (_isSearchExpanded || _isScrolledToTop)
        ? MediaQuery.of(context).size.height * 0.95
        : MediaQuery.of(context).size.height * 0.82;

    return ClipRRect(
      borderRadius: AppRadius.sheetRadius,
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: targetHeight,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + extraBottom),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.sheetRadius,
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: InteractiveDragHandle(
              color: Colors.white.withValues(alpha: 0.25),
              onTap: () => Navigator.pop(context),
              onVerticalDragUpdate: (details) {
                if ((details.primaryDelta ?? 0) > 3) {
                  Navigator.pop(context);
                }
              },
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),

          // ── Header Row / Expandable Search Bar ────────────────────────────
          AppSearchBar(
            mode: AppSearchBarMode.pill,
            title: 'Select Reason',
            pillLabel: 'Search',
            isExpanded: _isSearchExpanded,
            controller: _searchController,
            hint: 'Search reason or category...',
            autofocus: true,
            onExpandChanged: (expanded) {
              setState(() => _isSearchExpanded = expanded);
            },
            onChanged: (val) => setState(() => _searchQuery = val),
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

          // ── Scrollable Reasons List ───────────────────────────────────────
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels > 10 && !_isScrolledToTop) {
                  setState(() => _isScrolledToTop = true);
                }
                return false;
              },
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // ── Special Reasons Section ─────────────────────────────────
                  if (specialReasons.isNotEmpty) ...[
                    _buildSectionHeader('SPECIAL REASONS', Icons.star_outline_rounded),
                    const SizedBox(height: 6),
                    ...specialReasons.map((r) => _buildCompactSpecialTile(r)),
                    const SizedBox(height: 16),
                  ],

                  // ── Categories & Subcategories Section ──────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('CATEGORIES & SUBCATEGORIES', Icons.category_outlined),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showAddCategoryDialog(context, txVM),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, color: AppColors.positive, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Add Category',
                                style: TextStyle(
                                  color: AppColors.positive,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (topCategories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No categories found matching search.',
                          style: TextStyle(color: AppColors.textSoft, fontSize: 12),
                        ),
                      ),
                    ),
                  ...topCategories.map((cat) => _buildCompactCategoryAccordion(cat, txVM)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Sticky "Save Changes" Button (Fully Rounded Pill) ──
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppButton.primary(
              height: 48,
              text: _selectedReason != null
                  ? 'Save Changes (${_selectedReason!.name})'
                  : 'Save Changes',
              onPressed: () {
                if (_selectedReason != null) {
                  widget.onReasonSelected(_selectedReason!);
                }
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4, top: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.50), size: 12),
          const SizedBox(width: 5),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSoft,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSpecialTile(AppReason reason) {
    final isSelected = _isSelected(reason);
    final nameLower = reason.name.toLowerCase();

    IconData iconData = Icons.star_rounded;
    if (nameLower.contains('loan')) {
      iconData = Icons.handshake_outlined;
    } else if (nameLower == 'internal transfer') {
      iconData = Icons.swap_horiz_rounded;
    } else if (nameLower == 'cash') {
      iconData = Icons.payments_outlined;
    } else if (nameLower == 'pass-through' || nameLower == 'pass through' || nameLower == 'bounce') {
      iconData = Icons.undo_rounded;
    }

    final descText = _getSpecialDescription(reason.name);

    return AnimatedContainer(
      key: ValueKey('special_${reason.id ?? reason.name}'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.positive.withValues(alpha: 0.14)
            : AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedReason = reason;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.positive.withValues(alpha: 0.20)
                        : Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    color: isSelected ? AppColors.positive : Colors.white.withValues(alpha: 0.70),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.90),
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.positive : Colors.white24,
                  size: isSelected ? 18 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('food')) return Icons.restaurant;
    if (lower.contains('drink')) return Icons.local_cafe;
    if (lower.contains('transport')) return Icons.directions_car;
    if (lower.contains('housing') || lower.contains('rent')) return Icons.home;
    if (lower.contains('utility') || lower.contains('light')) return Icons.lightbulb;
    if (lower.contains('goods') || lower.contains('shopping')) return Icons.shopping_bag;
    if (lower.contains('entertainment') || lower.contains('movie')) return Icons.movie;
    if (lower.contains('health') || lower.contains('medical')) return Icons.medical_services;
    if (lower.contains('education') || lower.contains('school')) return Icons.school;
    if (lower.contains('investment') || lower.contains('saving')) return Icons.trending_up;
    if (lower.contains('salary')) return Icons.account_balance_wallet;
    if (lower.contains('mobile') || lower.contains('internet') || lower.contains('airtime')) return Icons.phone_android;
    if (lower.contains('loan')) return Icons.handshake_outlined;
    if (lower.contains('cash')) return Icons.payments_outlined;
    if (lower.contains('pass-through') || lower.contains('pass through') || lower.contains('bounce')) return Icons.undo_rounded;
    if (lower.contains('internal transfer')) return Icons.swap_horiz_rounded;
    return Icons.category_outlined;
  }

  Widget _buildCompactCategoryAccordion(AppReason category, TransactionsViewModel txVM) {
    final subcategories = txVM.subcategoriesFor(category.id!);
    final isExpanded = _expandedCategoryId == category.id || _searchQuery.isNotEmpty;
    final isCategorySelected = _isSelected(category);

    return AnimatedContainer(
      key: ValueKey('cat_${category.id}'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCategorySelected
            ? AppColors.positive.withValues(alpha: 0.14)
            : AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: Column(
          children: [
            InkWell(
              borderRadius: isExpanded
                  ? BorderRadius.vertical(top: Radius.circular(AppRadius.card))
                  : AppRadius.cardRadius,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedReason = category;
                  if (subcategories.isNotEmpty) {
                    _expandedCategoryId = isExpanded ? null : category.id;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCategorySelected
                            ? AppColors.positive.withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCategoryIcon(category.name),
                        color: isCategorySelected ? AppColors.positive : Colors.white.withValues(alpha: 0.70),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              color: isCategorySelected ? Colors.white : Colors.white.withValues(alpha: 0.90),
                              fontSize: 13.5,
                              fontWeight: isCategorySelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${subcategories.length} subcategories',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.40),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isCategorySelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: isCategorySelected ? AppColors.positive : Colors.white24,
                      size: isCategorySelected ? 18 : 16,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _expandedCategoryId = isExpanded ? null : category.id;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                          color: isCategorySelected ? AppColors.positive : Colors.white54,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 10, 8),
                child: Column(
                  children: [
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReasonTransactionsScreen(reason: category),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.list_alt_rounded, color: AppColors.positive, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'View ${category.name} Transactions',
                              style: const TextStyle(
                                color: AppColors.positive,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.positive, size: 11),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...subcategories.map((sub) {
                      final isSubSelected = _isSelected(sub);
                      return AnimatedContainer(
                        key: ValueKey('sub_${sub.id}'),
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSubSelected
                              ? AppColors.positive.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: AppRadius.cardRadius,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: AppRadius.cardRadius,
                          child: InkWell(
                            borderRadius: AppRadius.cardRadius,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _selectedReason = sub;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: isSubSelected
                                          ? AppColors.positive.withValues(alpha: 0.20)
                                          : Colors.white.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(sub.name != 'General' ? sub.name : category.name),
                                      color: isSubSelected
                                          ? AppColors.positive
                                          : Colors.white.withValues(alpha: 0.65),
                                      size: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      sub.name,
                                      style: TextStyle(
                                        color: isSubSelected
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.85),
                                        fontSize: 12.5,
                                        fontWeight: isSubSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isSubSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                    color: isSubSelected ? AppColors.positive : Colors.white12,
                                    size: isSubSelected ? 16 : 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton.secondary(
                        icon: Icons.add,
                        text: 'Add Subcategory',
                        fullWidth: false,
                        height: 34,
                        fontSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        onPressed: () => _showAddCategoryDialog(context, txVM, parentCategory: category),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
