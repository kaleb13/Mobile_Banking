import 'package:flutter/material.dart';
import 'reason_transactions_screen.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';

class ReasonSelectionSheet extends StatefulWidget {
  final AppReason? initialReason;
  final Function(AppReason) onReasonSelected;

  const ReasonSelectionSheet({
    super.key,
    this.initialReason,
    required this.onReasonSelected,
  });

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
    'bounce': 'Bounced, reversed & failed transactions',
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

  bool _isScrolledToTop = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final query = _searchQuery.trim().toLowerCase();

    final specialReasonsMap = <String, AppReason>{};
    for (var r in provider.reasons.where(_isSpecial)) {
      final nameKey = r.name.trim().toLowerCase();
      if (nameKey.contains(query)) {
        specialReasonsMap.putIfAbsent(nameKey, () => r);
      }
    }
    final specialReasons = specialReasonsMap.values.toList();

    final topCategoriesMap = <String, AppReason>{};
    for (var r in provider.topLevelCategories) {
      if (_isSpecial(r)) continue;
      final nameKey = r.name.trim().toLowerCase();
      final matchesName = nameKey.contains(query);
      final matchesSub = provider.subcategoriesFor(r.id!).any((sub) => sub.name.toLowerCase().contains(query));
      if (matchesName || matchesSub) {
        topCategoriesMap.putIfAbsent(nameKey, () => r);
      }
    }
    final topCategories = topCategoriesMap.values.toList();

    final targetHeight = (_isSearchExpanded || _isScrolledToTop)
        ? MediaQuery.of(context).size.height * 0.95
        : MediaQuery.of(context).size.height * 0.82;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: targetHeight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            height: 42,
            child: _isSearchExpanded
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search reason or category...',
                            hintStyle: const TextStyle(color: AppColors.textSoft, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.positive, size: 18),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: AppColors.positive.withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: AppColors.positive.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.positive),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearchExpanded = false;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Text(
                        'Select Reason',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearchExpanded = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, color: AppColors.positive, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Search',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  _buildSectionHeader('CATEGORIES & SUBCATEGORIES', Icons.category_outlined),
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
                  ...topCategories.map((cat) => _buildCompactCategoryAccordion(cat, provider)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Sticky Floating "Save Changes" Button ──────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8),
            color: AppColors.bgMid,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedReason != null) {
                    widget.onReasonSelected(_selectedReason!);
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.positive,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _selectedReason != null
                      ? 'Save Changes (${_selectedReason!.name})'
                      : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4, top: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.positive, size: 12),
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
    } else if (nameLower == 'bounce') {
      iconData = Icons.replay_rounded;
    }

    final descText = _getSpecialDescription(reason.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.positive.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.positive.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.positive.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconData,
            color: AppColors.positive,
            size: 14,
          ),
        ),
        title: Text(
          reason.name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          descText,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.positive, size: 16)
            : const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 14),
        onTap: () {
          setState(() {
            _selectedReason = reason;
          });
        },
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
    if (lower.contains('bounce')) return Icons.replay_rounded;
    if (lower.contains('internal transfer')) return Icons.swap_horiz_rounded;
    return Icons.category_outlined;
  }

  Widget _buildCompactCategoryAccordion(AppReason category, FinanceProvider provider) {
    final subcategories = provider.subcategoriesFor(category.id!);
    final isExpanded = _expandedCategoryId == category.id || _searchQuery.isNotEmpty;
    final isCategorySelected = _isSelected(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isCategorySelected
            ? AppColors.positive.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCategorySelected
              ? AppColors.positive.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.positive.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(category.name),
                color: AppColors.positive,
                size: 14,
              ),
            ),
            title: Text(
              category.name,
              style: TextStyle(
                color: isCategorySelected ? AppColors.positive : Colors.white,
                fontSize: 13,
                fontWeight: isCategorySelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${subcategories.length} subcategories',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCategorySelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.positive, size: 16)
                else
                  const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 14),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // Clicking only the arrow toggles expansion WITHOUT checking/selecting category
                    setState(() {
                      _expandedCategoryId = isExpanded ? null : category.id;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              // Clicking category body CHECKS/selects category AND expands if subcategories exist
              setState(() {
                _selectedReason = category;
                if (subcategories.isNotEmpty) {
                  _expandedCategoryId = isExpanded ? null : category.id;
                }
              });
            },
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: isSubSelected
                            ? AppColors.positive.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.015),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.positive.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getCategoryIcon(sub.name != 'General' ? sub.name : category.name),
                            color: AppColors.positive.withValues(alpha: 0.85),
                            size: 12,
                          ),
                        ),
                        title: Text(
                          sub.name,
                          style: TextStyle(
                            color: isSubSelected ? AppColors.positive : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSubSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSubSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.positive, size: 14)
                            : const Icon(Icons.radio_button_unchecked, color: Colors.white12, size: 12),
                        onTap: () {
                          setState(() {
                            _selectedReason = sub;
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Open Category Management screen to add new subcategories
                      },
                      icon: const Icon(Icons.add, color: AppColors.positive, size: 14),
                      label: Text(
                        'Add Subcategory under ${category.name}',
                        style: const TextStyle(color: AppColors.positive, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
