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
import '../../widgets/app_back_button.dart';
import '../../widgets/currency_symbol_widget.dart';

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
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showAddGoalSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: AppColors.background, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'New Goal',
                                style: TextStyle(
                                  color: AppColors.background,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
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

    String statusText = 'Active';
    Color badgeBg = AppColors.activeBadgeBg;
    Color badgeTextColor = AppColors.activeBadgeText;

    if (isOnHold) {
      statusText = 'On Hold';
      badgeBg = const Color(0xFFE5E7EB);
      badgeTextColor = const Color(0xFF374151);
    } else if (isCompleted) {
      statusText = 'Completed';
      badgeBg = AppColors.activeBadgeBg;
      badgeTextColor = AppColors.activeBadgeText;
    }

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
              color: AppColors.tabBackground,
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

                  // Fully rounded Active status tab at the top right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1520),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header info
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: Colors.white,
                    child: _buildGoalThumbnail(goal.imagePath),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CurrencyTextWidget(
                            amount: goal.savedAmount,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                            customFormattedStr: currencyFmt.format(goal.savedAmount),
                          ),
                          Text(
                            ' of ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          CurrencyTextWidget(
                            amount: goal.targetAmount,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                            customFormattedStr: currencyFmt.format(goal.targetAmount),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111821),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Saving Goal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${goal.title}"? This action cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSavingGoal(goal.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD / EDIT GOAL SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void _showAddGoalSheet(BuildContext context, {SavingGoal? goalToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  int _selectedIconIndex = 7; // default to Savings icon

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
        if (idx != -1) {
          _selectedIconIndex = idx;
        }
      }
      // Restore allocation settings
      _allocationMode = edit.allocationMode;
      _globalPct = edit.accountAllocations['*'] ?? 30.0;
      if (edit.allocationMode != AllocationMode.globalPercent) {
        _accountPcts = Map<String, double>.from(edit.accountAllocations);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _pickedImagePath = result.files.single.path!;
          _useCustomImage = true;
        });
      }
    } catch (_) {}
  }

  String get _finalImagePath {
    if (_useCustomImage && _pickedImagePath != null) {
      return _pickedImagePath!;
    }
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
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.goalToEdit != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E1520),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 24, 20, inset + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ───────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title ────────────────────────────────────────────────────────
            Text(
              isEditing ? 'Edit Saving Goal' : 'New Saving Goal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isEditing
                  ? 'Update your target, saved amount, or icon'
                  : 'Set a target price and track your progress',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),

            // ── FORM FIELDS (main content) ────────────────────────────────────
            _buildField(
              controller: _titleCtrl,
              label: 'Goal Name',
              hint: 'e.g. New Car, Dream House',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _targetCtrl,
              label: 'Target Amount (\$)',
              hint: 'e.g. 200,000',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _savedCtrl,
              label: 'Already Saved (\$)',
              hint: '0',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // ── Card Color / Gradient Selector ────────────────────────────────
            _buildThemeSelector(),
            const SizedBox(height: 20),

            // ── Live progress preview ─────────────────────────────────────────
            ValueListenableBuilder(
              valueListenable: _targetCtrl,
              builder: (_, __, ___) {
                return ValueListenableBuilder(
                  valueListenable: _savedCtrl,
                  builder: (_, __, ___) {
                    final target =
                        double.tryParse(_targetCtrl.text.trim()) ?? 0;
                    final saved =
                        double.tryParse(_savedCtrl.text.trim()) ?? 0;
                    if (target <= 0) return const SizedBox.shrink();
                    final pct = ((saved / target) * 100).clamp(0.0, 100.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress preview',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 6,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.positive),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                );
              },
            ),

            // ── Funding Source / Allocation Section (Moved UP & Spaced Comfortably)
            Consumer<FinanceProvider>(
              builder: (context, prov, _) {
                final accountNames = prov.allAccountNames;
                final balances = prov.latestBalancesMap;
                final fmt = NumberFormat('#,##0');

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111821),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle Header Row
                      GestureDetector(
                        onTap: () => setState(
                            () => _allocationExpanded = !_allocationExpanded),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.savingProgressGradStart
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppColors.savingProgressGradStart,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Funding Source',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _allocationMode == AllocationMode.globalPercent
                                        ? '${_globalPct.toStringAsFixed(0)}% of total balance'
                                        : _accountPcts.isEmpty
                                            ? 'Select specific account'
                                            : _accountPcts.entries
                                                .map((e) =>
                                                    '${e.key} ${e.value.toStringAsFixed(0)}%')
                                                .join(', '),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
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
                                color: Colors.white54,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Collapsible Content
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: _allocationExpanded
                            ? Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Mode selector pills
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          _modePill('All Accounts',
                                              AllocationMode.globalPercent),
                                          const SizedBox(width: 8),
                                          _modePill('One Account',
                                              AllocationMode.accountSpecific),
                                          const SizedBox(width: 8),
                                          _modePill('Multiple Accounts',
                                              AllocationMode.multiAccount),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Global percent slider
                                    if (_allocationMode ==
                                        AllocationMode.globalPercent) ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Allocation: ${_globalPct.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'ETB ${fmt.format(prov.totalBalance * _globalPct / 100)}',
                                            style: const TextStyle(
                                              color: AppColors.savingProgressGradStart,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 4,
                                          activeTrackColor:
                                              AppColors.savingProgressGradStart,
                                          inactiveTrackColor:
                                              Colors.white.withValues(alpha: 0.12),
                                          thumbColor:
                                              AppColors.savingProgressGradStart,
                                          overlayColor: AppColors
                                              .savingProgressGradStart
                                              .withValues(alpha: 0.15),
                                        ),
                                        child: Slider(
                                          value: _globalPct,
                                          min: 5,
                                          max: 100,
                                          divisions: 19,
                                          onChanged: (v) =>
                                              setState(() => _globalPct = v),
                                        ),
                                      ),
                                    ],

                                    // Account-specific / multi-account sliders
                                    if (_allocationMode !=
                                        AllocationMode.globalPercent) ...[
                                      if (accountNames.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Text(
                                            'No accounts detected yet — send or receive a transaction to auto-link accounts.',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.45),
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else
                                        ...accountNames.map((name) {
                                          final bal = balances[name] ?? 0;
                                          final pct = _accountPcts[name] ?? 0.0;
                                          final isSelected = pct > 0;
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.03),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () => setState(() {
                                                        if (isSelected) {
                                                          _accountPcts
                                                              .remove(name);
                                                        } else {
                                                          _accountPcts[name] =
                                                              50.0;
                                                          if (_allocationMode ==
                                                              AllocationMode
                                                                  .accountSpecific) {
                                                            _accountPcts
                                                                .removeWhere(
                                                                    (k, v) =>
                                                                        k !=
                                                                        name);
                                                          }
                                                        }
                                                      }),
                                                      child: AnimatedContainer(
                                                        duration: const Duration(
                                                            milliseconds: 160),
                                                        width: 20,
                                                        height: 20,
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? AppColors
                                                                  .savingProgressGradStart
                                                              : Colors
                                                                  .transparent,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? AppColors
                                                                    .savingProgressGradStart
                                                                : Colors.white38,
                                                            width: 1.5,
                                                          ),
                                                        ),
                                                        child: isSelected
                                                            ? const Icon(
                                                                Icons
                                                                    .check_rounded,
                                                                color:
                                                                    Colors.white,
                                                                size: 13)
                                                            : null,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? Colors.white
                                                              : Colors.white60,
                                                          fontSize: 13,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                  .normal,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      'ETB ${fmt.format(bal)}',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.4),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(height: 6),
                                                  SliderTheme(
                                                    data: SliderThemeData(
                                                      trackHeight: 3,
                                                      activeTrackColor: AppColors
                                                          .savingProgressGradStart,
                                                      inactiveTrackColor: Colors
                                                          .white
                                                          .withValues(
                                                              alpha: 0.1),
                                                      thumbColor: AppColors
                                                          .savingProgressGradStart,
                                                      overlayColor: AppColors
                                                          .savingProgressGradStart
                                                          .withValues(
                                                              alpha: 0.15),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Slider(
                                                            value: pct,
                                                            min: 5,
                                                            max: 100,
                                                            divisions: 19,
                                                            onChanged: (v) =>
                                                                setState(() =>
                                                                    _accountPcts[
                                                                            name] =
                                                                        v),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 36,
                                                          child: Text(
                                                            '${pct.toStringAsFixed(0)}%',
                                                            style:
                                                                const TextStyle(
                                                              color: AppColors
                                                                  .savingProgressGradStart,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }),
                                    ],
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Customize Icon / Image — TOGGLE SECTION ──────────────────────
            GestureDetector(
              onTap: () => setState(() =>
                  _iconSectionExpanded = !_iconSectionExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111821),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconSectionExpanded
                          ? Icons.palette_rounded
                          : Icons.palette_outlined,
                      color: _iconSectionExpanded
                          ? AppColors.gold
                          : Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Customize Icon / Image',
                        style: TextStyle(
                          color: _iconSectionExpanded
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Selected Icon / Custom Image Thumbnail Preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 28,
                        height: 28,
                        color: Colors.transparent,
                        child: _buildPreviewThumbnail(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _iconSectionExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white54, size: 20),
                    ),
                  ],
                ),
              ),
            ),

            // ── Collapsible Icon/Image Content (Inline Grid — No Overflow!) ───
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _iconSectionExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose Icon',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildIconGrid(),
                          const SizedBox(height: 14),

                          const Text(
                            'Or Upload a Photo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.white,
                                  child: _buildPreviewThumbnail(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.upload_rounded,
                                            color: Colors.white70, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Upload Photo',
                                          style: TextStyle(
                                            color: Colors.white70,
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
            ),
            const SizedBox(height: 24),

            // ── Save / Update button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  final title = _titleCtrl.text.trim();
                  final targetClean = _targetCtrl.text
                      .replaceAll(',', '')
                      .replaceAll(' ', '')
                      .replaceAll('\$', '')
                      .trim();
                  final savedClean = _savedCtrl.text
                      .replaceAll(',', '')
                      .replaceAll(' ', '')
                      .replaceAll('\$', '')
                      .trim();
                  final target = double.tryParse(targetClean) ?? 0;
                  final saved = double.tryParse(savedClean) ?? 0;

                  if (title.isEmpty || target <= 0) return;

                  final Map<String, double> allocMap =
                      _allocationMode == AllocationMode.globalPercent
                          ? {'*': _globalPct}
                          : Map<String, double>.from(_accountPcts);

                  if (isEditing) {
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
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isEditing ? 'Update Goal' : 'Save Goal',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.accentColor.withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
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
          border: Border.all(
            color: selected
                ? AppColors.savingProgressGradStart
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.savingProgressGradStart
                : Colors.white60,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Redesigned inline 4-column icon selection grid (Fixes 345px bottom overflow error)
  Widget _buildIconGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _iconOptions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final isSelected = !_useCustomImage && _selectedIconIndex == index;
        final opt = _iconOptions[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIconIndex = index;
              _useCustomImage = false;
              _pickedImagePath = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.06),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  opt['icon'] as IconData,
                  color: isSelected ? AppColors.gold : Colors.white70,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  opt['label'] as String,
                  style: TextStyle(
                    color: isSelected ? AppColors.gold : Colors.white60,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            fillColor: const Color(0xFF111821),
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

