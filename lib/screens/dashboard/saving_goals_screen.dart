import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/saving_goal.dart';
import '../../models/goal_feasibility.dart';
import '../../presentation/viewmodels/savings_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/analytics_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class SavingGoalsScreen extends StatefulWidget {
  const SavingGoalsScreen({super.key});

  @override
  State<SavingGoalsScreen> createState() => _SavingGoalsScreenState();
}

class _SavingGoalsScreenState extends State<SavingGoalsScreen> {
  final NumberFormat currencyFmt = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.background,
          child: SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                  child: Row(
                    children: [
                      const AppBackButton(),
                      const SizedBox(width: 10),
                      const Text(
                        'Saving Goals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      AppButton.primary(
                        text: 'New Goal',
                        icon: Icons.add_rounded,
                        fullWidth: false,
                        height: 28,
                        fontSize: 11.5,
                        iconSize: 13,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: () => _showAddGoalSheet(context),
                      ),
                    ],
                  ),
                ),

                // ── Goals List ───────────────────────────────────────────────
                Expanded(
                  child: Consumer3<SavingsViewModel, SettingsViewModel, AnalyticsViewModel>(
                    builder: (context, savingsVM, settingsVM, analyticsVM, child) {
                      final goals = savingsVM.savingGoals;

                      if (goals.isEmpty) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.fromLTRB(16, 60, 16, 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.savings_outlined,
                                    color: AppColors.gold,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'No Saving Goals Yet',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Set a target and track your savings progress',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                GestureDetector(
                                  onTap: () => _showAddGoalSheet(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 13),
                                    decoration: BoxDecoration(
                                      color: AppColors.buttonPrimary,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add,
                                            color: AppColors.buttonPrimaryText, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Goal',
                                          style: TextStyle(
                                            color: AppColors.buttonPrimaryText,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Sort: active/completed first, on_hold goals last, preserving priority order within active
                      final sortedGoals = List<SavingGoal>.from(goals)..sort((a, b) {
                        final aOnHold = a.status == 'on_hold';
                        final bOnHold = b.status == 'on_hold';
                        if (aOnHold && !bOnHold) return 1;
                        if (!aOnHold && bOnHold) return -1;
                        return a.priority.compareTo(b.priority);
                      });

                      return ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: sortedGoals.length,
                        onReorder: (oldIndex, newIndex) {
                          savingsVM.reorderGoals(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 8,
                            shadowColor: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) => Padding(
                          key: ValueKey(sortedGoals[index].id),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildGoalCard(
                            context,
                            sortedGoals[index],
                            savingsVM,
                            settingsVM,
                            analyticsVM,
                            dragIndex: index,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GOAL CARD (Minimalist, Clean AppCard without Gradients)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGoalCard(
      BuildContext context,
      SavingGoal goal,
      SavingsViewModel savingsVM,
      SettingsViewModel settingsVM,
      AnalyticsViewModel analyticsVM,
      {int dragIndex = 0}) {
    final feasibility = savingsVM.goalFeasibility(
      goal,
      liveBalances: analyticsVM.latestBalancesMap,
      totalBalance: analyticsVM.totalBalance,
    );
    final isOnHold = goal.status == 'on_hold';
    final allocatedFromBanks = isOnHold ? 0.0 : feasibility.availableAmount;
    final totalCovered =
        (goal.savedAmount + allocatedFromBanks).clamp(0.0, goal.targetAmount);
    final fraction = goal.targetAmount > 0
        ? (totalCovered / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final pctInt = (fraction * 100).round();
    final isCompleted = totalCovered >= goal.targetAmount;

    Widget cardWidget = AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Thumbnail + Title / Target + Status & Priority Badges + Drag Handle ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Goal thumbnail / icon
              _buildGoalThumbnail(goal.imagePath, size: 48),
              const SizedBox(width: 14),

              // Title and Target
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          settingsVM.isBalanceVisible
                              ? 'Target: ${currencyFmt.format(goal.targetAmount)}'
                              : 'Target: ••••••••',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (settingsVM.isBalanceVisible) ...[
                          const SizedBox(width: 3),
                          const CurrencySymbolWidget(
                            size: 11,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Badges Column (Status + Priority)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isCompleted)
                    const AppBadge.success(
                      text: 'Ready',
                      size: AppBadgeSize.small,
                    )
                  else if (isOnHold)
                    const AppBadge.neutral(
                      text: 'On Hold',
                      size: AppBadgeSize.small,
                    )
                  else
                    const AppBadge.success(
                      text: 'Active',
                      size: AppBadgeSize.small,
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.buttonSecondary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '#${goal.priority} Priority',
                      style: const TextStyle(
                        color: AppColors.positive,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 4),

              // Reorder drag handle
              ReorderableDragStartListener(
                index: dragIndex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Progress Bar ──
          CustomProgressBar(
            progress: fraction,
            height: 22,
            backgroundColor: AppColors.tabBackground,
            progressColor: isCompleted
                ? AppColors.positive
                : AppColors.emeraldBright,
            centerLabel: '$pctInt% Covered',
            labelInFilledOnly: false,
            labelStyle: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // ── Covered vs Remaining Metrics ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Covered: ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    settingsVM.isBalanceVisible
                        ? currencyFmt.format(totalCovered)
                        : '••••••••',
                    style: const TextStyle(
                      color: AppColors.positive,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (settingsVM.isBalanceVisible) ...[
                    const SizedBox(width: 2),
                    const CurrencySymbolWidget(
                      size: 10,
                      color: AppColors.positive,
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Remaining: ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    settingsVM.isBalanceVisible
                        ? currencyFmt.format((goal.targetAmount - totalCovered).clamp(0, double.infinity))
                        : '••••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (settingsVM.isBalanceVisible) ...[
                    const SizedBox(width: 2),
                    const CurrencySymbolWidget(
                      size: 10,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ],
          ),

          // ── Feasibility note / warning inside the card ──
          if (!isOnHold && (feasibility.hasConflict || feasibility.canAffordNow || allocatedFromBanks > 0)) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 8),
            _buildFeasibilityRow(feasibility, allocatedFromBanks: allocatedFromBanks),
          ],
        ],
      ),
    );

    // Apply Grayscale Filter for On-Hold goals
    if (isOnHold) {
      cardWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.85, 0,
        ]),
        child: cardWidget,
      );
    }

    return GestureDetector(
      onTap: () => _showGoalOptionsSheet(context, goal, savingsVM),
      child: cardWidget,
    );
  }

  Widget _buildFeasibilityRow(GoalFeasibility f,
      {double allocatedFromBanks = 0.0}) {
    if (f.hasConflict) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.negative, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              f.conflictWarning,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.negative,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else if (f.canAffordNow) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.positive, size: 13),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              '100% funded • Ready to achieve',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.positive,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else if (allocatedFromBanks > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.positive, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'ETB ${currencyFmt.format(allocatedFromBanks)} allocated from live bank balances',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildGoalThumbnail(String imagePath, {double size = 48}) {
    Widget innerContent;

    if (imagePath.startsWith('/')) {
      final file = File(imagePath);
      if (file.existsSync()) {
        innerContent = Image.file(
          file,
          fit: BoxFit.cover,
          width: size,
          height: size,
        );
      } else {
        innerContent = Icon(
          Icons.savings_rounded,
          size: size * 0.52,
          color: AppColors.positive,
        );
      }
    } else if (imagePath.startsWith('assets/')) {
      innerContent = Padding(
        padding: EdgeInsets.all(size * 0.15),
        child: Image.asset(imagePath, fit: BoxFit.contain),
      );
    } else {
      final iconData = _getGoalIconData(imagePath);
      innerContent = Icon(
        iconData,
        size: size * 0.52,
        color: AppColors.background,
      );
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: size,
          height: size,
          color: Colors.white, // White image background section
          alignment: Alignment.center,
          child: innerContent,
        ),
      ),
    );
  }

  static IconData _getGoalIconData(String imagePath) {
    if (imagePath.startsWith('icon:')) {
      final key = imagePath.substring(5);
      switch (key) {
        case 'car':
          return Icons.directions_car_rounded;
        case 'home':
          return Icons.home_rounded;
        case 'travel':
          return Icons.flight_rounded;
        case 'tech':
          return Icons.laptop_mac_rounded;
        case 'education':
          return Icons.school_rounded;
        case 'health':
          return Icons.favorite_rounded;
        case 'shopping':
          return Icons.shopping_bag_rounded;
        case 'savings':
          return Icons.savings_rounded;
        case 'fitness':
          return Icons.directions_bike_rounded;
        case 'food':
          return Icons.restaurant_rounded;
        case 'music':
          return Icons.music_note_rounded;
        case 'vacation':
          return Icons.beach_access_rounded;
      }
    }
    return Icons.savings_rounded;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARD OPTIONS MENU (Tap on Card)
  // ─────────────────────────────────────────────────────────────────────────
  void _showGoalOptionsSheet(
      BuildContext context, SavingGoal goal, SavingsViewModel savingsVM) {
    final analyticsVM = Provider.of<AnalyticsViewModel>(context, listen: false);
    final feasibility = savingsVM.goalFeasibility(
      goal,
      liveBalances: analyticsVM.latestBalancesMap,
      totalBalance: analyticsVM.totalBalance,
    );
    final isOnHold = goal.status == 'on_hold';
    final allocatedFromBanks = isOnHold ? 0.0 : feasibility.availableAmount;
    final totalCovered =
        (goal.savedAmount + allocatedFromBanks).clamp(0.0, goal.targetAmount);
    final fraction = goal.targetAmount > 0
        ? (totalCovered / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final pctInt = (fraction * 100).round();

    AppDrawer.show(
      context: context,
      builder: (ctx) => AppDrawer(
        headerCard: AppDrawerHeaderCard(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              color: Colors.white,
              child: _buildGoalThumbnail(goal.imagePath),
            ),
          ),
          title: goal.title,
          subtitle:
              '${currencyFmt.format(totalCovered)} ETB of ${currencyFmt.format(goal.targetAmount)} ETB ($pctInt% covered)',
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Edit Goal
            _buildOptionTile(
              icon: Icons.edit_rounded,
              iconColor: Colors.white,
              title: 'Edit Goal',
              subtitle: 'Change title, target, saved amount, or icon',
              onTap: () {
                Navigator.pop(ctx);
                _showAddGoalSheet(context, goalToEdit: goal);
              },
            ),

            // 2. Put on Hold / Reactivate
            _buildOptionTile(
              icon: goal.status == 'on_hold'
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              iconColor: goal.status == 'on_hold'
                  ? AppColors.positive
                  : AppColors.gold,
              title: goal.status == 'on_hold'
                  ? 'Reactivate Goal'
                  : 'Put on Hold',
              subtitle: goal.status == 'on_hold'
                  ? 'Move this goal back to active goals'
                  : 'Pause progress and move card to the bottom in black & white',
              onTap: () {
                Navigator.pop(ctx);
                final updated = goal.copyWith(
                  status: goal.status == 'on_hold' ? 'active' : 'on_hold',
                );
                savingsVM.updateSavingGoal(updated);
              },
            ),

            // 3. Delete Goal
            _buildOptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: AppColors.destructiveRed,
              title: 'Delete Goal',
              subtitle: 'Permanently remove this saving goal',
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteGoal(context, goal, savingsVM);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.buttonSecondary,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.buttonSoftDestructiveBg
                      : AppColors.buttonSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? AppColors.destructiveRed : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteGoal(
      BuildContext context, SavingGoal goal, SavingsViewModel savingsVM) {
    AppConfirmDialog.show(
      context: context,
      title: 'Delete Saving Goal',
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.negative,
      message:
          'Are you sure you want to delete "${goal.title}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () {
        savingsVM.deleteSavingGoal(goal.id);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD / EDIT GOAL SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void _showAddGoalSheet(BuildContext context, {SavingGoal? goalToEdit}) {
    AppDrawer.show(
      context: context,
      builder: (ctx) => _AddGoalSheet(goalToEdit: goalToEdit),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Goal Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddGoalSheet extends StatefulWidget {
  final SavingGoal? goalToEdit;
  const _AddGoalSheet({this.goalToEdit});

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _savedCtrl;
  String? _pickedImagePath;
  bool _useCustomImage = false;
  bool _iconSectionExpanded = false;

  // ── Priority & Allocation state ─────────────────────────────────
  int _priority = 1;
  AllocationMode _allocationMode = AllocationMode.globalPercent;
  double _globalPct = 100.0; // default 100% of global
  Map<String, double> _accountPcts = {};
  bool _allocationExpanded = true;

  static const _iconOptions = <Map<String, dynamic>>[
    {'icon': Icons.directions_car_rounded,  'label': 'Car',       'id': 'icon:car'},
    {'icon': Icons.home_rounded,            'label': 'Home',      'id': 'icon:home'},
    {'icon': Icons.flight_rounded,          'label': 'Travel',    'id': 'icon:travel'},
    {'icon': Icons.laptop_mac_rounded,      'label': 'Tech',      'id': 'icon:tech'},
    {'icon': Icons.school_rounded,          'label': 'Education', 'id': 'icon:education'},
    {'icon': Icons.favorite_rounded,        'label': 'Health',    'id': 'icon:health'},
    {'icon': Icons.shopping_bag_rounded,    'label': 'Shopping',  'id': 'icon:shopping'},
    {'icon': Icons.savings_rounded,         'label': 'Savings',   'id': 'icon:savings'},
    {'icon': Icons.directions_bike_rounded, 'label': 'Fitness',   'id': 'icon:fitness'},
    {'icon': Icons.restaurant_rounded,      'label': 'Food',      'id': 'icon:food'},
    {'icon': Icons.music_note_rounded,      'label': 'Music',     'id': 'icon:music'},
    {'icon': Icons.beach_access_rounded,    'label': 'Vacation',  'id': 'icon:vacation'},
  ];
  int _selectedIconIndex = 7;

  @override
  void initState() {
    super.initState();
    final edit = widget.goalToEdit;
    _titleCtrl = TextEditingController(text: edit?.title ?? '');
    _targetCtrl = TextEditingController(
        text: edit != null ? edit.targetAmount.toStringAsFixed(0) : '');
    _savedCtrl = TextEditingController(
        text: edit != null ? edit.savedAmount.toStringAsFixed(0) : '0');

    if (edit != null) {
      _priority = edit.priority;
      if (edit.imagePath.startsWith('/')) {
        _pickedImagePath = edit.imagePath;
        _useCustomImage = true;
        _iconSectionExpanded = true;
      } else if (edit.imagePath.startsWith('icon:')) {
        final idx = _iconOptions.indexWhere((opt) => opt['id'] == edit.imagePath);
        if (idx != -1) _selectedIconIndex = idx;
      }
      _allocationMode = edit.allocationMode == AllocationMode.globalPercent
          ? AllocationMode.globalPercent
          : AllocationMode.multiAccount;
      _globalPct = edit.accountAllocations['*'] ?? 100.0;
      if (edit.allocationMode != AllocationMode.globalPercent) {
        _accountPcts = Map<String, double>.from(edit.accountAllocations);
      }
    } else {
      final existingGoals = context.read<SavingsViewModel>().savingGoals;
      _priority = existingGoals.length + 1;
    }
  }

  double _calculateAllocatedFromBanks(
    Map<String, double> balances,
    double totalBalance,
  ) {
    if (_allocationMode == AllocationMode.globalPercent) {
      return (totalBalance * (_globalPct / 100.0)).clamp(0.0, double.infinity);
    }
    double sum = 0.0;
    _accountPcts.forEach((acc, pct) {
      final b = balances[acc] ?? 0.0;
      sum += b * (pct / 100.0);
    });
    return sum.clamp(0.0, double.infinity);
  }

  void _saveGoal() {
    final title = _titleCtrl.text.trim();
    final targetClean = _targetCtrl.text.replaceAll(',', '').replaceAll(' ', '').replaceAll('\$', '').trim();
    final savedClean = _savedCtrl.text.replaceAll(',', '').replaceAll(' ', '').replaceAll('\$', '').trim();
    final target = double.tryParse(targetClean) ?? 0;
    final saved = double.tryParse(savedClean) ?? 0;

    if (title.isEmpty || target <= 0) return;

    final Map<String, double> allocMap =
        _allocationMode == AllocationMode.globalPercent
            ? {'*': _globalPct}
            : Map<String, double>.from(_accountPcts);

    if (widget.goalToEdit != null) {
      final updated = widget.goalToEdit!.copyWith(
        title: title,
        targetAmount: target,
        savedAmount: saved,
        imagePath: _finalImagePath,
        priority: _priority,
        allocationMode: _allocationMode,
        accountAllocations: allocMap,
        colorTheme: 'green',
      );
      context.read<SavingsViewModel>().updateSavingGoal(updated);
    } else {
      final newGoal = SavingGoal(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        targetAmount: target,
        savedAmount: saved,
        imagePath: _finalImagePath,
        priority: _priority,
        allocationMode: _allocationMode,
        accountAllocations: allocMap,
        colorTheme: 'green',
      );
      context.read<SavingsViewModel>().addSavingGoal(newGoal);
    }
    Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _pickedImagePath = result.files.single.path!;
          _useCustomImage = true;
        });
      }
    } catch (_) {}
  }

  String get _finalImagePath {
    if (_useCustomImage && _pickedImagePath != null) return _pickedImagePath!;
    if (_selectedIconIndex >= 0 && _selectedIconIndex < _iconOptions.length) {
      return _iconOptions[_selectedIconIndex]['id'] as String;
    }
    return 'icon:savings';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.goalToEdit != null;

    return AppDrawer(
      heightFactor: 0.88,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.savings_outlined,
        iconColor: AppColors.positive,
        title: isEditing ? 'Edit Saving Goal' : 'New Saving Goal',
        subtitle: isEditing
            ? 'Update your target, priority, or bank allocations'
            : 'Set a target amount, priority rank, and funding allocation',
      ),
      bottomAction: AppButton.primary(
        text: isEditing ? 'Update Goal' : 'Save Goal',
        height: 48,
        onPressed: _saveGoal,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildField(
            controller: _titleCtrl,
            label: 'Goal Name',
            hint: 'e.g. New Car, Dream House',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _targetCtrl,
            label:
                'Target Amount (${Provider.of<SettingsViewModel>(context, listen: false).currentCurrency.shortLabel})',
            hint: 'e.g. 200,000',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _savedCtrl,
            label:
                'Already Saved (${Provider.of<SettingsViewModel>(context, listen: false).currentCurrency.shortLabel})',
            hint: '0',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // ── Goal Priority Stepper ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.previewCardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.format_list_numbered_rounded,
                      color: AppColors.positive, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Goal Priority Rank',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 1),
                      Text('Priority #1 claims available funds first',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_priority > 1) {
                          setState(() => _priority--);
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.buttonSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.remove_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '#$_priority',
                        style: const TextStyle(
                          color: AppColors.positive,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _priority++);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.buttonSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Dynamic Live Progress & Coverage Preview ──
          Consumer<AnalyticsViewModel>(
            builder: (context, analyticsVM, _) {
              final balances = analyticsVM.latestBalancesMap;
              final totalBal = analyticsVM.totalBalance;
              final fmt = NumberFormat('#,##0');
              final currencyLabel = Provider.of<SettingsViewModel>(context, listen: false)
                  .currentCurrency
                  .shortLabel;

              return ListenableBuilder(
                listenable: Listenable.merge([_targetCtrl, _savedCtrl]),
                builder: (_, __) {
                  final target = double.tryParse(_targetCtrl.text.trim()) ?? 0.0;
                  final manualSaved = double.tryParse(_savedCtrl.text.trim()) ?? 0.0;
                  final allocatedFromBanks =
                      _calculateAllocatedFromBanks(balances, totalBal);
                  final totalCovered = manualSaved + allocatedFromBanks;
                  final progressPct = target > 0
                      ? ((totalCovered / target) * 100.0).clamp(0.0, 100.0)
                      : 0.0;

                  if (target <= 0) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.previewCardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Coverage: ${fmt.format(totalCovered)} of ${fmt.format(target)} $currencyLabel',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${progressPct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: AppColors.positive,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomProgressBar(
                          progress: progressPct / 100.0,
                          height: 10,
                          progressColor: AppColors.positive,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bank allocation: ${fmt.format(allocatedFromBanks)} $currencyLabel',
                              style: const TextStyle(
                                color: AppColors.positive,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (manualSaved > 0)
                              Text(
                                'Manual saved: ${fmt.format(manualSaved)} $currencyLabel',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // ── Funding Source & Allocation (Global % and Custom %) ──
          Consumer<AnalyticsViewModel>(
            builder: (context, prov, _) {
              final accountNames = prov.allAccountNames;
              final balances = prov.latestBalancesMap;
              final totalBal = prov.totalBalance;
              final fmt = NumberFormat('#,##0');
              final globalAllocated = totalBal * (_globalPct / 100.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.previewCardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _allocationExpanded = !_allocationExpanded),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.positive.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.positive,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Funding Source & Allocation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Choose how bank balances fund this goal',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _allocationExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_allocationExpanded) ...[
                      const SizedBox(height: 14),
                      AppPrimaryTabBar(
                        tabs: const ['Global %', 'Custom %'],
                        selectedIndex: _allocationMode == AllocationMode.globalPercent ? 0 : 1,
                        onTabChanged: (idx) {
                          setState(() {
                            if (idx == 0) {
                              _allocationMode = AllocationMode.globalPercent;
                            } else {
                              _allocationMode = AllocationMode.multiAccount;
                              if (_accountPcts.isEmpty && accountNames.isNotEmpty) {
                                _accountPcts[accountNames.first] = 100.0;
                              }
                            }
                          });
                        },
                        backgroundColor: AppColors.tabBackground,
                        margin: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 14),
                      if (_allocationMode == AllocationMode.globalPercent) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Global Balance: ETB ${fmt.format(totalBal)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              'ETB ${fmt.format(globalAllocated)}',
                              style: const TextStyle(
                                color: AppColors.positive,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: AppColors.positive,
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                                  thumbColor: Colors.white,
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                ),
                                child: Slider(
                                  value: _globalPct,
                                  min: 5,
                                  max: 100,
                                  divisions: 19,
                                  onChanged: (v) => setState(() => _globalPct = v),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.positive.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '${_globalPct.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppColors.positive,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'Select bank accounts and assign custom % allocations:',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (accountNames.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No bank accounts detected yet.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          )
                        else
                          ...accountNames.map((name) {
                            final bal = balances[name] ?? 0.0;
                            final isSelected = _accountPcts.containsKey(name);
                            final pct = _accountPcts[name] ?? 100.0;
                            final accAllocated = bal * (pct / 100.0);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.positive.withValues(alpha: 0.10)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          if (isSelected) {
                                            _accountPcts.remove(name);
                                          } else {
                                            _accountPcts[name] = 100.0;
                                          }
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 160),
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.positive
                                                : Colors.white.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check_rounded,
                                                  color: Colors.black, size: 13)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : AppColors.textSecondary,
                                            fontSize: 12.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        isSelected
                                            ? 'ETB ${fmt.format(accAllocated)} (${pct.toStringAsFixed(0)}%)'
                                            : 'ETB ${fmt.format(bal)}',
                                        style: TextStyle(
                                          color: isSelected ? AppColors.positive : AppColors.textSecondary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderThemeData(
                                              activeTrackColor: AppColors.positive,
                                              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                                              thumbColor: Colors.white,
                                              trackHeight: 3,
                                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                            ),
                                            child: Slider(
                                              value: pct,
                                              min: 5,
                                              max: 100,
                                              divisions: 19,
                                              onChanged: (v) => setState(() {
                                                _accountPcts[name] = v;
                                              }),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.positive.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            '${pct.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              color: AppColors.positive,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () => setState(() => _iconSectionExpanded = !_iconSectionExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.previewCardBg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(_iconSectionExpanded ? Icons.palette_rounded : Icons.palette_outlined, color: _iconSectionExpanded ? AppColors.positive : AppColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Customize Icon / Image', style: TextStyle(color: _iconSectionExpanded ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(width: 28, height: 28, color: Colors.transparent, child: _buildPreviewThumbnail())),
                  const SizedBox(width: 8),
                  AnimatedRotation(turns: _iconSectionExpanded ? 0.5 : 0.0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20)),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: _iconSectionExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _iconSectionExpanded
                ? Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.previewCardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose an Icon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Inline Icon Grid
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_iconOptions.length, (i) {
                            final item = _iconOptions[i];
                            final isSel =
                                !_useCustomImage && _selectedIconIndex == i;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIconIndex = i;
                                  _useCustomImage = false;
                                });
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppColors.positive.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: isSel
                                      ? AppColors.positive
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Divider text
                        const Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white12)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'or use photo',
                                style: TextStyle(
                                    color: AppColors.textSoft, fontSize: 11),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.white12)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Upload Photo Row
                        Row(
                          children: [
                            if (_pickedImagePath != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_pickedImagePath!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppColors.buttonSecondary,
                                    borderRadius: BorderRadius.all(Radius.circular(100)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Upload Photo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Preview thumbnail rendered in positive tint background container with dark/accent icon
  Widget _buildPreviewThumbnail() {
    if (_useCustomImage && _pickedImagePath != null) {
      final file = File(_pickedImagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    final iconData = _selectedIconIndex >= 0 && _selectedIconIndex < _iconOptions.length
        ? _iconOptions[_selectedIconIndex]['icon'] as IconData
        : Icons.savings_rounded;

    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.positive.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(iconData, color: AppColors.positive, size: 16),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: keyboardType,
      backgroundColor: AppColors.previewCardBg,
      borderRadius: BorderRadius.circular(16),
    );
  }
}

