import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';

/// Top-down 3/4 screen height drawer for transaction categorization.
///
/// Displayed inside the transparent [TransactionQuickEditActivity].
/// Features grouped parent categories, drill-down subcategories ("Go Deeper"),
/// static direction & amount strip, Save button, and Open App link.
class QuickEditOverlay extends StatefulWidget {
  const QuickEditOverlay({super.key});

  @override
  State<QuickEditOverlay> createState() => _QuickEditOverlayState();
}

class _QuickEditOverlayState extends State<QuickEditOverlay>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.shibre/quick_edit');

  String _bankName = '';
  String _amount = '';
  String _direction = '';

  List<_CategoryGroup> _categoryGroups = [];
  int? _expandedGroupId;
  int? _selectedReasonId;
  String? _selectedReasonName;
  bool _loaded = false;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _loadTransactionData();
  }

  Future<void> _loadTransactionData() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getTransactionData',
      );
      if (data == null) return;

      final reasonsList = (data['reasons'] as List?)?.cast<Map>() ?? [];

      setState(() {
        _bankName = data['bankName'] as String? ?? '';
        _amount = data['amount'] as String? ?? '';
        _direction = data['direction'] as String? ?? '';

        // Separate parents (parentId == null && !isSpecial) and subcategories
        final allReasons = reasonsList
            .map((m) => _ReasonItem(
                  id: m['id'] as int,
                  name: m['name'] as String,
                  parentId: m['parentId'] as int?,
                  isSpecial: (m['isSpecial'] as bool?) ?? false,
                ))
            .where((r) => !r.isSpecial)
            .toList();

        final parents = allReasons.where((r) => r.parentId == null).toList();

        if (parents.isEmpty) {
          // Provide clean default grouped categories if DB has no parent structure
          _categoryGroups = [
            _CategoryGroup(
              parent: const _ReasonItem(id: 1, name: 'Food & Dining'),
              subcategories: const [
                _ReasonItem(id: 101, name: 'Restaurants', parentId: 1),
                _ReasonItem(id: 102, name: 'Groceries', parentId: 1),
                _ReasonItem(id: 103, name: 'Fast Food', parentId: 1),
                _ReasonItem(id: 104, name: 'Coffee & Snacks', parentId: 1),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 2, name: 'Goods & Shopping'),
              subcategories: const [
                _ReasonItem(id: 201, name: 'Clothing & Apparel', parentId: 2),
                _ReasonItem(id: 202, name: 'Electronics', parentId: 2),
                _ReasonItem(id: 203, name: 'Household Goods', parentId: 2),
                _ReasonItem(id: 204, name: 'Supermarket', parentId: 2),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 3, name: 'Bills & Utilities'),
              subcategories: const [
                _ReasonItem(id: 301, name: 'Electricity & Water', parentId: 3),
                _ReasonItem(id: 302, name: 'Airtime & Internet', parentId: 3),
                _ReasonItem(id: 303, name: 'Rent', parentId: 3),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 4, name: 'Transport & Travel'),
              subcategories: const [
                _ReasonItem(id: 401, name: 'Taxi / Ride Share', parentId: 4),
                _ReasonItem(id: 402, name: 'Fuel & Gas', parentId: 4),
                _ReasonItem(id: 403, name: 'Public Transit', parentId: 4),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 5, name: 'Financial & Transfer'),
              subcategories: const [
                _ReasonItem(id: 501, name: 'Person Transfer', parentId: 5),
                _ReasonItem(id: 502, name: 'Loan Repayment', parentId: 5),
                _ReasonItem(id: 503, name: 'Salary & Income', parentId: 5),
              ],
            ),
          ];
        } else {
          _categoryGroups = parents.map((p) {
            final subs = allReasons.where((r) {
              if (r.parentId != p.id) return false;
              final pName = p.name.toLowerCase();
              final rName = r.name.toLowerCase();
              if ((pName.contains('food') || pName.contains('drink')) &&
                  (rName.contains('loan') || rName.contains('borrow') || rName.contains('lend'))) {
                return false;
              }
              return true;
            }).toList();
            return _CategoryGroup(parent: p, subcategories: subs);
          }).toList();
        }

        _loaded = true;
      });

      _animController.forward();
    } catch (e) {
      debugPrint('QuickEditOverlay: failed to load data: $e');
    }
  }

  void _selectReason(_ReasonItem item) {
    setState(() {
      _selectedReasonId = item.id;
      _selectedReasonName = item.name;
    });
  }

  void _toggleGroup(_CategoryGroup group) {
    setState(() {
      if (_expandedGroupId == group.parent.id) {
        _expandedGroupId = null;
      } else {
        _expandedGroupId = group.parent.id;
      }
    });
  }

  Future<void> _save() async {
    if (_selectedReasonName == null) return;
    try {
      await _channel.invokeMethod('saveReason', {
        'reasonName': _selectedReasonName,
        'reasonId': _selectedReasonId,
      });
    } catch (e) {
      debugPrint('QuickEditOverlay: save failed: $e');
    }
  }

  Future<void> _openApp() async {
    try {
      await _channel.invokeMethod('openApp');
    } catch (_) {}
    SystemNavigator.pop();
  }

  Future<void> _dismiss() async {
    try {
      await _channel.invokeMethod('dismiss');
    } catch (_) {}
    SystemNavigator.pop();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final threeQuarterHeight = mediaQuery.size.height * 0.75;

    return GestureDetector(
      onTap: _dismiss,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {}, // Absorb taps on top drawer
                child: _loaded
                    ? FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _buildTopDrawer(
                              context, topPadding, threeQuarterHeight),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDrawer(
      BuildContext context, double topPadding, double threeQuarterHeight) {
    final isExpense = _direction.toLowerCase().contains('sent') ||
        _direction.toLowerCase().contains('to') ||
        _direction.toLowerCase().contains('paid');

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: threeQuarterHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 36,
            spreadRadius: 4,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drawer Handle & Title Section ──────────────────────
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.positive.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: AppColors.positive,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Categorize Transaction',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _direction.isNotEmpty
                                ? _direction
                                : 'Banking Transaction from $_bankName',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Static Transferred / Deposited Amount Strip ────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                                      ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isExpense
                                  ? AppColors.warning
                                  : AppColors.positive)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpense
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: isExpense
                              ? AppColors.warning
                              : AppColors.positive,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isExpense
                                  ? 'Transferred Amount'
                                  : 'Deposited Amount',
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _amount.isNotEmpty ? _amount : 'ETB 0.00',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Grouped Categories List ────────────────────────────
                const Text(
                  'SELECT CATEGORY',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _categoryGroups.length,
                    itemBuilder: (context, index) {
                      final group = _categoryGroups[index];
                      return _buildGroupCard(group);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bottom Action Row (Save & Open App) ─────────────────
                Row(
                  children: [
                    Expanded(
                      child: AppButton.primary(
                        text: _selectedReasonName != null
                            ? 'Save as "$_selectedReasonName"'
                            : 'Select Category',
                        height: 46,
                        onPressed: _selectedReasonName != null ? _save : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton.secondary(
                      text: 'Open App',
                      icon: Icons.arrow_forward_rounded,
                      fullWidth: false,
                      height: 46,
                      onPressed: _openApp,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(_CategoryGroup group) {
    final isParentSelected = _selectedReasonId == group.parent.id;
    final isExpanded = _expandedGroupId == group.parent.id;
    final hasSubcategories = group.subcategories.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isParentSelected
            ? AppColors.positive.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
              ),
      child: Column(
        children: [
          // Parent Category Tile
          InkWell(
            onTap: () {
              _selectReason(group.parent);
              if (hasSubcategories && !isExpanded) {
                setState(() => _expandedGroupId = group.parent.id);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(group.parent.name),
                    size: 18,
                    color: isParentSelected
                        ? AppColors.positive
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.parent.name,
                      style: TextStyle(
                        color: isParentSelected ? Colors.white : Colors.white70,
                        fontSize: 13.5,
                        fontWeight: isParentSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasSubcategories) ...[
                    AppBadge.success(
                      text: 'Go deeper',
                      icon: isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.chevron_right_rounded,
                      size: AppBadgeSize.small,
                      onTap: () => _toggleGroup(group),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Subcategories Expanded Panel
          if (hasSubcategories && isExpanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: group.subcategories.map((sub) {
                  final isSubSelected = _selectedReasonId == sub.id;
                  return GestureDetector(
                    onTap: () => _selectReason(sub),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSubSelected
                            ? AppColors.positive.withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                                              ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSubSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 11,
                            color: isSubSelected
                                ? AppColors.positive
                                : AppColors.textSoft,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            sub.name,
                            style: TextStyle(
                              color: isSubSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: isSubSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('food') || lower.contains('dining')) {
      return Icons.restaurant_rounded;
    } else if (lower.contains('goods') || lower.contains('shopping')) {
      return Icons.shopping_bag_outlined;
    } else if (lower.contains('bill') || lower.contains('utility')) {
      return Icons.bolt_rounded;
    } else if (lower.contains('transport') || lower.contains('travel')) {
      return Icons.directions_bus_rounded;
    } else if (lower.contains('financial') || lower.contains('transfer')) {
      return Icons.swap_horiz_rounded;
    } else if (lower.contains('health') || lower.contains('medical')) {
      return Icons.local_hospital_outlined;
    } else if (lower.contains('education')) {
      return Icons.school_outlined;
    } else if (lower.contains('entertainment')) {
      return Icons.movie_outlined;
    }
    return Icons.category_outlined;
  }
}

class _ReasonItem {
  final int id;
  final String name;
  final int? parentId;
  final bool isSpecial;

  const _ReasonItem({
    required this.id,
    required this.name,
    this.parentId,
    this.isSpecial = false,
  });
}

class _CategoryGroup {
  final _ReasonItem parent;
  final List<_ReasonItem> subcategories;

  const _CategoryGroup({
    required this.parent,
    required this.subcategories,
  });
}
