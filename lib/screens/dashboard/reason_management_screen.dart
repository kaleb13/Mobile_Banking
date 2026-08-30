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
import 'category_linked_persons_drawer.dart';

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
    'pass-through': "Pass-through money that doesn't belong to you",
    'pass through': "Pass-through money that doesn't belong to you",
    'bounce': "Pass-through money that doesn't belong to you",
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
                  maxLength: 40,
                  autofocus: true,
                  hint: isSubcategory ? 'Subcategory name...' : 'Category name...',
                  borderRadius: BorderRadius.circular(16),
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
    // Check if any person is linked to this reason or its subcategories
    final linked = reason.isTopLevelCategory
        ? txVM.allLinksForCategoryTree(reason.id!)
        : txVM.linksForReason(reason.id!);

    if (linked.isNotEmpty) {
      AppConfirmDialog.show(
        context: context,
        title: 'Cannot Delete Reason',
        icon: Icons.link_rounded,
        iconColor: AppColors.warning,
        message:
            'This ${reason.isSubcategory ? 'subcategory' : 'category'} has ${linked.length} person(s) currently linked to it (${linked.map((l) => '"${l.linkedName}"').take(3).join(', ')}${linked.length > 3 ? '...' : ''}).\n\nPlease unlink all persons before deleting this reason.',
        confirmText: 'View Linked Persons',
        cancelText: 'Close',
        isDestructive: false,
        onConfirm: () {
          CategoryLinkedPersonsDrawer.show(context, reason: reason);
        },
      );
      return;
    }

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
    final linkedList = reason.isTopLevelCategory
        ? txVM.allLinksForCategoryTree(reason.id!)
        : txVM.linksForReason(reason.id!);

    AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        return AppDrawer(
          headerCard: AppDrawerHeaderCard(
            icon: AppColors.getCategoryIcon(reason.name),
            title: reason.name,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDrawerActionTile(
                icon: Icons.people_outline_rounded,
                title: 'Linked Persons (${linkedList.length})',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  CategoryLinkedPersonsDrawer.show(context, reason: reason);
                },
              ),
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
                AppDrawerActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Add Subcategory',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showAddCategoryDialog(context, txVM, parentCategory: reason);
                  },
                ),
              ] else ...[
                AppDrawerActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit / Rename',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showAddCategoryDialog(context, txVM, existing: reason);
                  },
                ),
                if (reason.isTopLevelCategory)
                  AppDrawerActionTile(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Add Subcategory',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _showAddCategoryDialog(context, txVM, parentCategory: reason);
                    },
                  ),
                AppDrawerActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: reason.isTopLevelCategory ? 'Delete Category' : 'Delete Subcategory',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmDeleteCategory(context, txVM, reason);
                  },
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
          bottom: true,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 80),
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
          Icon(icon, color: Colors.white.withValues(alpha: 0.50), size: 14),
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
    final linkedCount = txVM.allLinksForCategoryTree(category.id!).length;

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
                  if (linkedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AppBadge.neutral(
                        icon: Icons.link_rounded,
                        text: '$linkedCount',
                        size: AppBadgeSize.small,
                      ),
                    ),
                  if (_isProtectedTopCategory(category))
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: AppBadge.info(
                        text: 'System',
                        size: AppBadgeSize.small,
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${subcategories.length} subcategories${linkedCount > 0 ? ' • $linkedCount linked' : ''}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.people_outline_rounded,
                      color: linkedCount > 0 ? Colors.white70 : Colors.white30,
                      size: 19,
                    ),
                    tooltip: 'Linked Persons',
                    onPressed: () =>
                        CategoryLinkedPersonsDrawer.show(context, reason: category),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
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
                      final subLinkedCount = txVM.linksForReason(sub.id!).length;

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
                            onTap: () => _showCategoryOptionsModal(context, txVM, sub),
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
                                  if (subLinkedCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: AppBadge.neutral(
                                        icon: Icons.link_rounded,
                                        text: '$subLinkedCount',
                                        size: AppBadgeSize.micro,
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
