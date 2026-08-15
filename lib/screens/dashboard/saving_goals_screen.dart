import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/saving_goal.dart';
import '../../models/goal_feasibility.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_drawer.dart';

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
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Row(
                    children: [
                      const AppBackButton(),
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
                  child: Consumer<FinanceProvider>(
                    builder: (context, provider, child) {
                      final goals = provider.savingGoals;

                      if (goals.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111821),
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
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Set a target and track your savings progress',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add,
                                          color: AppColors.background, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Add Your First Goal',
                                        style: TextStyle(
                                          color: AppColors.background,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Sort: active/completed first, on_hold goals last
                      final sortedGoals = List<SavingGoal>.from(goals)..sort((a, b) {
                        final aOnHold = a.status == 'on_hold';
                        final bOnHold = b.status == 'on_hold';
                        if (aOnHold && !bOnHold) return 1;
                        if (!aOnHold && bOnHold) return -1;
                        return 0;
                      });

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        physics: const BouncingScrollPhysics(),
                        itemCount: sortedGoals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 20),
                        itemBuilder: (context, index) =>
                            _buildGoalCard(context, sortedGoals[index], provider),
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
  // GOAL CARD
  // Structure:
  //   ┌──────────────────────────────────────┐  ← red gradient card (full)
  //   │  ┌────────────────────────────────┐  │  ← white rounded info box
  //   │  │  [img]  title / price / badge  │  │
  //   │  └────────────────────────────────┘  │
  //   │                                      │
  //   │  P R O G R E S S   (on gradient)    │
  //   │  [===●──────────────]               │
  //   │  $saved               $remaining    │
  //   └──────────────────────────────────────┘
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGoalCard(
      BuildContext context, SavingGoal goal, FinanceProvider provider) {
    final feasibility = provider.goalFeasibility(goal);
    final fraction = goal.targetAmount > 0
        ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final pctInt = (fraction * 100).round();

    final isOnHold = goal.status == 'on_hold';
    final isCompleted = goal.savedAmount >= goal.targetAmount;

    final theme = GoalGradientTheme.fromId(goal.colorTheme);

    Widget cardWidget = Container(
      // ── Outer card: Mesh/Linear Gradient background ───────────────────────
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Info Box — Dark background ──────────────
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Goal image/icon thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 62,
                          height: 62,
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: _buildGoalThumbnail(goal.imagePath, size: 62),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Goal text info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 65),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Goal',
                                style: TextStyle(
                                  color: Color(0xFF8E95A2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
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
                              Text(
                                currencyFmt.format(goal.targetAmount),
                                style: TextStyle(
                                  color: theme.accentColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Fully rounded Active / Completed / On Hold status badge at the top right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: isCompleted
                        ? const AppBadge.success(
                            text: 'Completed',
                            size: AppBadgeSize.small,
                          )
                        : isOnHold
                            ? const AppBadge.neutral(
                                text: 'On Hold',
                                size: AppBadgeSize.small,
                              )
                            : const AppBadge.success(
                                text: 'Active',
                                size: AppBadgeSize.small,
                              ),
                  ),
                ],
              ),
            ),

            // ── Progress section — directly on the gradient background ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  const Center(
                    child: Text(
                      'P R O G R E S S',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress bar
                  CustomProgressBar(
                    progress: fraction,
                    height: 22,
                    backgroundColor: theme.darkProgressBg,
                    progressGradient: LinearGradient(
                      colors: [
                        theme.accentColor,
                        theme.accentColor.withValues(alpha: 0.85),
                      ],
                    ),
                    centerLabel: '$pctInt%',
                    labelInFilledOnly: true,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom text: Left accent color and Right White
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currencyFmt.format(goal.savedAmount),
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        currencyFmt.format(goal.targetAmount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // ── Feasibility chip — rendered BELOW the card ──────────────────────────
    Widget chipRow = _buildFeasibilityChip(feasibility, goal);

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
      onTap: () => _showGoalOptionsSheet(context, goal, provider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cardWidget,
          chipRow,
        ],
      ),
    );
  }

  Widget _buildFeasibilityChip(GoalFeasibility f, SavingGoal goal) {
    if (goal.status == 'on_hold') return const SizedBox.shrink();

    if (f.hasConflict) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                f.conflictWarning,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (f.canAffordNow) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.positive, size: 13),
            const SizedBox(width: 5),
            const Flexible(
              child: Text(
                'You can afford this now',
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
        ),
      );
    }

    // Text saying "% covered by your allocation" removed per user request
    return const SizedBox.shrink();
  }

  Widget _buildGoalThumbnail(String imagePath, {double size = 62}) {
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
          size: size * 0.5,
          color: AppColors.background,
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
      BuildContext context, SavingGoal goal, FinanceProvider provider) {
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
          subtitle: '${currencyFmt.format(goal.savedAmount)} ETB of ${currencyFmt.format(goal.targetAmount)} ETB',
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
                provider.updateSavingGoal(updated);
              },
            ),

            // 3. Delete Goal
            _buildOptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: const Color(0xFFFF5252),
              title: 'Delete Goal',
              subtitle: 'Permanently remove this saving goal',
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteGoal(context, goal, provider);
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
        splashColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.07),
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
                        color: isDestructive ? const Color(0xFFFF5252) : Colors.white,
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
      BuildContext context, SavingGoal goal, FinanceProvider provider) {
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
        provider.deleteSavingGoal(goal.id);
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
  bool _iconSectionExpanded = false; // collapsed by default

  // ── Allocation state ────────────────────────────────────────────
  AllocationMode _allocationMode = AllocationMode.globalPercent;
  double _globalPct = 30.0; // % of total balance (global mode)
  Map<String, double> _accountPcts = {};
  bool _allocationExpanded = true; // comfortable expanded state by default

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

  String _selectedThemeId = 'green';

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
      _selectedThemeId = edit.colorTheme;
      if (edit.imagePath.startsWith('/')) {
        _pickedImagePath = edit.imagePath;
        _useCustomImage = true;
        _iconSectionExpanded = true;
      } else if (edit.imagePath.startsWith('icon:')) {
        final idx = _iconOptions.indexWhere((opt) => opt['id'] == edit.imagePath);
        if (idx != -1) _selectedIconIndex = idx;
      }
      _allocationMode = edit.allocationMode;
      _globalPct = edit.accountAllocations['*'] ?? 30.0;
      if (edit.allocationMode != AllocationMode.globalPercent) {
        _accountPcts = Map<String, double>.from(edit.accountAllocations);
      }
    }
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
        allocationMode: _allocationMode,
        accountAllocations: allocMap,
        colorTheme: _selectedThemeId,
      );
      context.read<FinanceProvider>().updateSavingGoal(updated);
    } else {
      final newGoal = SavingGoal(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        targetAmount: target,
        savedAmount: saved,
        imagePath: _finalImagePath,
        allocationMode: _allocationMode,
        accountAllocations: allocMap,
        colorTheme: _selectedThemeId,
      );
      context.read<FinanceProvider>().addSavingGoal(newGoal);
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
        iconColor: AppColors.gold,
        title: isEditing ? 'Edit Saving Goal' : 'New Saving Goal',
        subtitle: isEditing
            ? 'Update your target, saved amount, or icon'
            : 'Set a target price and track your progress',
      ),
      bottomAction: AppButton.primary(
        text: isEditing ? 'Update Goal' : 'Save Goal',
        height: 48,
        onPressed: _saveGoal,
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
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
                'Target Amount (${Provider.of<FinanceProvider>(context, listen: false).currentCurrency.shortLabel})',
            hint: 'e.g. 200,000',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _savedCtrl,
            label:
                'Already Saved (${Provider.of<FinanceProvider>(context, listen: false).currentCurrency.shortLabel})',
            hint: '0',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildThemeSelector(),
          const SizedBox(height: 20),
          ValueListenableBuilder(
            valueListenable: _targetCtrl,
            builder: (_, __, ___) {
              return ValueListenableBuilder(
                valueListenable: _savedCtrl,
                builder: (_, __, ___) {
                  final target = double.tryParse(_targetCtrl.text.trim()) ?? 0;
                  final saved = double.tryParse(_savedCtrl.text.trim()) ?? 0;
                  if (target <= 0) return const SizedBox.shrink();
                  final pct = ((saved / target) * 100).clamp(0.0, 100.0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progress preview', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CustomProgressBar(
                        progress: pct / 100,
                        height: 10,
                        progressColor: AppColors.positive,
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              );
            },
          ),
          Consumer<FinanceProvider>(
            builder: (context, prov, _) {
              final accountNames = prov.allAccountNames;
              final balances = prov.latestBalancesMap;
              final fmt = NumberFormat('#,##0');
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.previewCardBg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _allocationExpanded = !_allocationExpanded),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: AppColors.savingProgressGradStart.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.savingProgressGradStart, size: 15),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Funding Source & Allocation', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                                SizedBox(height: 1),
                                Text('Choose how your bank balances count toward this goal', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                              ],
                            ),
                          ),
                          AnimatedRotation(turns: _allocationExpanded ? 0.5 : 0.0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20)),
                        ],
                      ),
                    ),
                    if (_allocationExpanded) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _modePill('Global %', AllocationMode.globalPercent),
                          const SizedBox(width: 6),
                          _modePill('Specific Bank', AllocationMode.accountSpecific),
                          const SizedBox(width: 6),
                          _modePill('Custom %', AllocationMode.multiAccount),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_allocationMode == AllocationMode.globalPercent) ...[
                        Text('Use ${_globalPct.toStringAsFixed(0)}% of your total balance across ALL accounts.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(activeTrackColor: AppColors.savingProgressGradStart, inactiveTrackColor: Colors.white.withValues(alpha: 0.12), thumbColor: Colors.white, trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
                                child: Slider(value: _globalPct, min: 5, max: 100, divisions: 19, onChanged: (v) => setState(() => _globalPct = v)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.savingProgressGradStart.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text('${_globalPct.toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.savingProgressGradStart, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(_allocationMode == AllocationMode.accountSpecific ? 'Select ONE bank account to fund this goal:' : 'Assign custom % to multiple bank accounts:', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                        const SizedBox(height: 8),
                        if (accountNames.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No bank accounts detected yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)))
                        else
                          ...accountNames.map((name) {
                            final bal = balances[name] ?? 0.0;
                            final isSelected = _accountPcts.containsKey(name);
                            final pct = _accountPcts[name] ?? 50.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: isSelected ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(10)),
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
                                            _accountPcts[name] = 50.0;
                                            if (_allocationMode == AllocationMode.accountSpecific) {
                                              _accountPcts.removeWhere((k, v) => k != name);
                                            }
                                          }
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 160),
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(color: isSelected ? AppColors.savingProgressGradStart : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                                          child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 13) : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(name, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                                      Text('ETB ${fmt.format(bal)}', style: TextStyle(color: isSelected ? AppColors.positive : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  if (isSelected && _allocationMode == AllocationMode.multiAccount) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderThemeData(activeTrackColor: AppColors.savingProgressGradStart, inactiveTrackColor: Colors.white.withValues(alpha: 0.1), thumbColor: Colors.white, trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                                            child: Slider(value: pct, min: 5, max: 100, divisions: 19, onChanged: (v) => setState(() => _accountPcts[name] = v)),
                                          ),
                                        ),
                                        Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.savingProgressGradStart, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  Icon(_iconSectionExpanded ? Icons.palette_rounded : Icons.palette_outlined, color: _iconSectionExpanded ? AppColors.gold : AppColors.textSecondary, size: 18),
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
                                      ? AppColors.gold.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: isSel
                                      ? AppColors.gold
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
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_rounded,
                                          color: AppColors.textSecondary, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Upload Photo',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
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

  /// Horizontal gradient color theme selector
  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Card Color Theme',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: GoalGradientTheme.themes.map((theme) {
            final isSelected = _selectedThemeId == theme.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedThemeId = theme.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.gradientColors,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Pill-shaped mode selector tab
  Widget _modePill(String label, AllocationMode mode) {
    final selected = _allocationMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _allocationMode = mode;
        if (mode == AllocationMode.globalPercent) _accountPcts.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.savingProgressGradStart.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.savingProgressGradStart
                : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Preview thumbnail rendered in white background container with dark icon
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(iconData, color: AppColors.background, size: 18),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: AppColors.previewCardBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goal Gradient Themes
// ─────────────────────────────────────────────────────────────────────────────
class GoalGradientTheme {
  final String id;
  final String name;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color darkProgressBg;

  const GoalGradientTheme({
    required this.id,
    required this.name,
    required this.gradientColors,
    required this.accentColor,
    required this.darkProgressBg,
  });

  static const green = GoalGradientTheme(
    id: 'green',
    name: 'Emerald Green',
    gradientColors: [
      Color(0xFF059669),
      Color(0xFF047857),
      Color(0xFF065F46),
    ],
    accentColor: Color(0xFF10B981),
    darkProgressBg: Color(0xFF064E3B),
  );

  static const red = GoalGradientTheme(
    id: 'red',
    name: 'Crimson Red',
    gradientColors: [
      Color(0xFFD55B43),
      Color(0xFF8B2231),
      Color(0xFF9A2551),
    ],
    accentColor: Color(0xFFFF6846),
    darkProgressBg: Color(0xFF7E1C30),
  );

  static const purple = GoalGradientTheme(
    id: 'purple',
    name: 'Royal Purple',
    gradientColors: [
      Color(0xFF7C3AED),
      Color(0xFF5B21B6),
      Color(0xFF4C1D95),
    ],
    accentColor: Color(0xFFA855F7),
    darkProgressBg: Color(0xFF3B0764),
  );

  static const blue = GoalGradientTheme(
    id: 'blue',
    name: 'Midnight Blue',
    gradientColors: [
      Color(0xFF2563EB),
      Color(0xFF1E40AF),
      Color(0xFF1E3A8A),
    ],
    accentColor: Color(0xFF3B82F6),
    darkProgressBg: Color(0xFF172554),
  );

  static const List<GoalGradientTheme> themes = [
    green,
    red,
    purple,
    blue,
  ];

  static GoalGradientTheme fromId(String? id) {
    return themes.firstWhere(
      (t) => t.id == id,
      orElse: () => green,
    );
  }
}

