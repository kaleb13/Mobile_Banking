import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';

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
      context.read<FinanceProvider>().loadReasons();
    });
  }

  bool _isSpecial(AppReason r) {
    if (r.isSpecial) return true;
    final nameLower = r.name.trim().toLowerCase();
    return _specialReasonDescriptions.containsKey(nameLower);
  }

  void _showAddCategoryDialog(BuildContext context, FinanceProvider provider, {AppReason? parentCategory, AppReason? existing}) {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    final isSubcategory = parentCategory != null || (existing != null && existing.isSubcategory);

    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        return StatefulBuilder(builder: (ctx, setInner) {
          return AlertDialog(
            backgroundColor: AppColors.bgMid,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              existing == null
                  ? (isSubcategory ? 'New Subcategory' : 'New Category')
                  : (isSubcategory ? 'Edit Subcategory' : 'Edit Category'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parentCategory != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Parent: ${parentCategory.name}',
                      style: const TextStyle(color: AppColors.positive, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) {
                    if (errorMsg != null) setInner(() => errorMsg = null);
                  },
                  decoration: InputDecoration(
                    hintText: isSubcategory ? 'Subcategory name...' : 'Category name...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
                ],
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              AppButton.secondary(
                text: 'Cancel',
                fullWidth: false,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: () => Navigator.pop(ctx),
              ),
              const SizedBox(width: 8),
              AppButton.primary(
                text: 'Save',
                fullWidth: false,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;

                  if (existing != null) {
                    await provider.updateCategory(existing.id!, name);
                  } else if (parentCategory != null) {
                    await provider.addSubcategory(parentCategory.id!, name);
                  } else {
                    await provider.addTopLevelCategory(name);
                  }

                  if (context.mounted) {
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, FinanceProvider provider, AppReason reason) {
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
        await provider.deleteCategory(reason.id!);
      },
    );
  }

  void _showCategoryOptionsModal(BuildContext context, FinanceProvider provider, AppReason reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                reason.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                reason.isSubcategory ? 'Subcategory Options' : 'Category Options',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white70),
                title: const Text('Edit / Rename', style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showAddCategoryDialog(context, provider, existing: reason);
                },
              ),
              if (reason.isTopLevelCategory)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.positive),
                  title: const Text('Add Subcategory', style: TextStyle(color: AppColors.positive, fontSize: 14, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showAddCategoryDialog(context, provider, parentCategory: reason);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.negative),
                title: const Text('Delete', style: TextStyle(color: AppColors.negative, fontSize: 14, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmDeleteCategory(context, provider, reason);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    final specialReasonsMap = <String, AppReason>{};
    for (var r in provider.reasons.where(_isSpecial)) {
      specialReasonsMap.putIfAbsent(r.name.trim().toLowerCase(), () => r);
    }
    final specialReasons = specialReasonsMap.values.toList();

    final topCategoriesMap = <String, AppReason>{};
    for (var r in provider.topLevelCategories) {
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
          onPressed: () => _showAddCategoryDialog(context, provider),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
            children: [
              // ── Header ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 12),
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
              ...topCategories.map((cat) => _buildCategoryCard(context, provider, cat)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
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
    );
  }

  Widget _buildSpecialReasonCard(AppReason reason) {
    final nameLower = reason.name.trim().toLowerCase();
    final descText = _specialReasonDescriptions[nameLower] ?? 'Core System Reason';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.positive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'System',
              style: TextStyle(color: AppColors.positive, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, FinanceProvider provider, AppReason category) {
    final subcategories = provider.subcategoriesFor(category.id!);
    final isExpanded = _expandedCategoryId == category.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              title: Text(
                category.name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
                _showCategoryOptionsModal(context, provider, category);
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
                            onLongPress: () => _showCategoryOptionsModal(context, provider, sub),
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
                        onPressed: () => _showAddCategoryDialog(context, provider, parentCategory: category),
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
