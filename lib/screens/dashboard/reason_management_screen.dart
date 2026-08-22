import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_modal_dialog.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_drawer.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

// Alias for backwards compatibility with existing imports
typedef ReasonManagementScreen = CategoryManagementScreen;

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  int? _expandedCategoryId;

  static const Map<String, String> _specialReasonDescriptions = {
    'loan': 'Track loans, credit lines & debt repayments',
    'internal transfer': 'Transfer money between your accounts',
    'cash': 'Cash wallet & manual cash expenses',
    'bounce': 'Bounced, reversed & failed transactions',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionsViewModel>().loadReasons();
    });
  }

  bool _isSpecial(AppReason r) {
    if (r.isSpecial) return true;
    final nameLower = r.name.trim().toLowerCase();
    return _specialReasonDescriptions.containsKey(nameLower);
  }

  void _showAddCategoryDialog(BuildContext context, TransactionsViewModel txVM, {AppReason? parentCategory, AppReason? existing}) {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    final isSubcategory = parentCategory != null || (existing != null && existing.isSubcategory);

    AppModalDialog.show(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        return StatefulBuilder(builder: (ctx, setInner) {
          return AppModalDialog(
            title: existing == null
                ? (isSubcategory ? 'New Subcategory' : 'New Category')
                : (isSubcategory ? 'Edit Subcategory' : 'Edit Category'),
            subtitle: parentCategory != null ? 'Parent: ${parentCategory.name}' : null,
            confirmText: 'Save',
            cancelText: 'Cancel',
            onConfirm: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;

              if (existing != null) {
                await txVM.updateCategory(existing.id!, name);
              } else if (parentCategory != null) {
                await txVM.addSubcategory(parentCategory.id!, name);
              } else {
                await txVM.addTopLevelCategory(name);
              }

              if (context.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField.modal(
                  controller: ctrl,
                  autofocus: true,
                  hint: isSubcategory ? 'Subcategory name...' : 'Category name...',
                  borderRadius: AppRadius.cardRadiusSm,
                  onChanged: (_) {
                    if (errorMsg != null) setInner(() => errorMsg = null);
                  },
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, TransactionsViewModel txVM, AppReason reason) {
    AppConfirmDialog.show(
      context: context,
      title: reason.isSubcategory ? 'Delete Subcategory?' : 'Delete Category?',
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.negative,
      message: reason.isSubcategory
          ? 'Are you sure you want to delete "${reason.name}"?'
          : 'Are you sure you want to delete "${reason.name}" and all of its subcategories?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () async {
        await txVM.deleteCategory(reason.id!);
      },
    );
  }

  bool _isProtectedTopCategory(AppReason reason) {
    return reason.isTopLevelCategory &&
        reason.name.trim().toLowerCase() == 'mobile & internet';
  }

  bool _isProtectedSubcategory(AppReason reason) {
    if (!reason.isSubcategory) return false;
    final nameLower = reason.name.trim().toLowerCase();
    return nameLower == 'airtime' || nameLower == 'package';
  }

  void _showCategoryOptionsModal(BuildContext context, TransactionsViewModel txVM, AppReason reason) {
    final isTopProtected = _isProtectedTopCategory(reason);
    final isSubProtected = _isProtectedSubcategory(reason);

    AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        return AppDrawer(
          headerCard: AppDrawerHeaderCard(
            icon: Icons.category_outlined,
            iconColor: AppColors.positive,
            title: reason.name,
            subtitle: isSubProtected
                ? 'System Locked Reason'
                : isTopProtected
                    ? 'System Category'
                    : reason.isSubcategory
                        ? 'Subcategory Options'
                        : 'Category Options',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSubProtected)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'This is a locked system reason used for automatic SMS transaction detection. It cannot be renamed or deleted.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                )
              else if (isTopProtected) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'This is a core system category and cannot be renamed or deleted. You can still add, edit, or remove custom subcategories inside it.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                    leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.positive),
                    title: const Text('Add Subcategory', style: TextStyle(color: AppColors.positive, fontSize: 14, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _showAddCategoryDialog(context, txVM, parentCategory: reason);
                    },
                  ),
                ),
              ] else ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                    leading: const Icon(Icons.edit_outlined, color: Colors.white70),
                    title: const Text('Edit / Rename', style: TextStyle(color: Colors.white, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _showAddCategoryDialog(context, txVM, existing: reason);
                    },
                  ),
                ),
                if (reason.isTopLevelCategory)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                      leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.positive),
                      title: const Text('Add Subcategory', style: TextStyle(color: AppColors.positive, fontSize: 14, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _showAddCategoryDialog(context, txVM, parentCategory: reason);
                      },
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.08),
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.negative),
                    title: const Text('Delete', style: TextStyle(color: AppColors.negative, fontSize: 14, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _confirmDeleteCategory(context, txVM, reason);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context);

    final specialReasonsMap = <String, AppReason>{};
    for (var r in txVM.reasons.where(_isSpecial)) {
      specialReasonsMap.putIfAbsent(r.name.trim().toLowerCase(), () => r);
    }
    final specialReasons = specialReasonsMap.values.toList();

    final topCategoriesMap = <String, AppReason>{};
    for (var r in txVM.topLevelCategories) {
      if (!_isSpecial(r)) {
        topCategoriesMap.putIfAbsent(r.name.trim().toLowerCase(), () => r);
      }
    }
    final topCategories = topCategoriesMap.values.toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: AppButton.primary(
          text: 'Add Category',
          icon: Icons.add_rounded,
          fullWidth: false,
          height: 48,
          elevation: 6.0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          onPressed: () => _showAddCategoryDialog(context, txVM),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 100),
            children: [
              // ── Header ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 16, 20),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 10),
                    const Text(
                      'Category Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Special Reasons (Read-only System Core) ─────────
              if (specialReasons.isNotEmpty) ...[
                _sectionHeader('SPECIAL REASONS', Icons.star_outline_rounded),
                const SizedBox(height: 10),
                ...specialReasons.map((r) => _buildSpecialReasonCard(r)),
                const SizedBox(height: 24),
              ],

              // ── Top-Level Categories & Subcategories ─────────────
              _sectionHeader('CATEGORIES & SUBCATEGORIES', Icons.category_outlined),
              const SizedBox(height: 10),
              if (topCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No categories created yet.', style: TextStyle(color: AppColors.textSoft, fontSize: 13)),
                  ),
                ),
              ...topCategories.map((cat) => _buildCategoryCard(context, txVM, cat)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.positive, size: 14),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialReasonCard(AppReason reason) {
    final nameLower = reason.name.trim().toLowerCase();
    final descText = _specialReasonDescriptions[nameLower] ?? 'Core System Reason';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  descText,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const AppBadge.info(
            text: 'System',
            size: AppBadgeSize.small,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, TransactionsViewModel txVM, AppReason category) {
    final subcategories = txVM.subcategoriesFor(category.id!);
    final isExpanded = _expandedCategoryId == category.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardRadius,
        child: Column(
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_isProtectedTopCategory(category))
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: AppBadge.info(
                        text: 'System',
                        size: AppBadgeSize.small,
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${subcategories.length} subcategories',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              trailing: Icon(
                isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                color: Colors.white54,
                size: 20,
              ),
              onTap: () {
                setState(() {
                  _expandedCategoryId = isExpanded ? null : category.id;
                });
              },
              onLongPress: () {
                _showCategoryOptionsModal(context, txVM, category);
              },
            ),
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(
                  children: [
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 6),
                    ...subcategories.map((sub) {
                      final isSubLocked = _isProtectedSubcategory(sub);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onLongPress: () => _showCategoryOptionsModal(context, txVM, sub),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sub.name,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                  if (isSubLocked)
                                    const AppBadge.info(
                                      text: 'Locked',
                                      size: AppBadgeSize.small,
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
