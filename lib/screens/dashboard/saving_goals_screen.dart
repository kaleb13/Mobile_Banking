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
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
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
    // ── Progress Logic ──────────────────────────────────────────────────────
    // Use the feasibility engine — available money earmarked for this goal.
    final feasibility = provider.goalFeasibility(goal);
    // Card progress = manual savedAmount vs target (pure manual tracking)
    final fraction = goal.targetAmount > 0
        ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final pctInt = (fraction * 100).round();

    final isOnHold = goal.status == 'on_hold';
    final isCompleted = goal.savedAmount >= goal.targetAmount;

    String statusText = 'Active';
    Color badgeBg = AppColors.activeBadgeBg;      // 0xFFDCFCE7
    Color badgeTextColor = AppColors.activeBadgeText; // 0xFF166534

    if (isOnHold) {
      statusText = 'On Hold';
      badgeBg = const Color(0xFFE5E7EB);
      badgeTextColor = const Color(0xFF374151);
    } else if (isCompleted) {
      statusText = 'Completed';
      badgeBg = AppColors.activeBadgeBg;
      badgeTextColor = AppColors.activeBadgeText;
    }

    Widget cardWidget = Container(
      // ── Outer card: Mesh/Linear Gradient background ───────────────────────
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.savingCardTopLeft,     // 0xFFD55B43
            AppColors.savingCardCenter,      // 0xFF8B2231
            AppColors.savingCardBottomRight, // 0xFF9A2551
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Info Box — Dark background, NO border radius ──────────────
            Container(
              width: double.infinity,
              color: AppColors.tabBackground, // Flat dark top background
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Goal image thumbnail — transparent background, height matching 3 texts
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

                      // Goal text info (3 texts: Goal label, Title, Target amount)
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
                                style: const TextStyle(
                                  color: AppColors.savingProgressGradStart, // 0xFFFF6846
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
                        borderRadius: BorderRadius.circular(20), // Fully rounded capsule
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
                  // P R O G R E S S text
                  const Center(
                    child: Text(
                      'P R O G R E S S',
                      style: TextStyle(
                        color: Color(0xFFF4A8B7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress bar — compact height 22px
                  CustomProgressBar(
                    progress: fraction,
                    height: 22,
                    backgroundColor: AppColors.savingProgressDark, // 0xFF7E1C30
                    progressGradient: const LinearGradient(
                      colors: [
                        AppColors.savingProgressGradStart, // 0xFFFF6846
                        AppColors.savingProgressGradEnd,   // 0xFFFE9F99
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

                  // Bottom text: Left FF6846 and Right White
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currencyFmt.format(goal.savedAmount),
                        style: const TextStyle(
                          color: AppColors.savingProgressGradStart, // 0xFFFF6846
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        currencyFmt.format(goal.targetAmount),
                        style: const TextStyle(
                          color: Colors.white, // Right text white
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

    Color chipText;
    IconData chipIcon;
    String chipLabel;

    if (f.hasConflict) {
      chipText = const Color(0xFFFF6B6B);
      chipIcon = Icons.warning_amber_rounded;
      chipLabel = f.conflictWarning;
    } else if (f.canAffordNow) {
      chipText = AppColors.positive;
      chipIcon = Icons.check_circle_rounded;
      chipLabel = 'You can afford this now';
    } else {
      final coverPct = (f.coverageRatio * 100).toStringAsFixed(0);
      chipText = const Color(0xFFE6B84A);
      chipIcon = Icons.hourglass_bottom_rounded;
      chipLabel = '$coverPct% covered by your allocation';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, color: chipText, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              chipLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chipText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalThumbnail(String imagePath, {double size = 62}) {
    if (imagePath.startsWith('/')) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: size,
              height: size,
            ),
          ),
        );
      }
    }
    if (imagePath.startsWith('assets/')) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      );
    }
    // Fallback icon
    return Center(
      child: Icon(Icons.savings_outlined, size: size * 0.55, color: AppColors.gold),
    );
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
                      Text(
                        '\$ ${currencyFmt.format(goal.savedAmount)} of \$ ${currencyFmt.format(goal.targetAmount)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
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
  final String _selectedIcon = 'assets/images/Saving_Goal_Icon.png';
  bool _useCustomImage = false;
  bool _iconSectionExpanded = false; // collapsed by default

  // ── Allocation state ────────────────────────────────────────────
  AllocationMode _allocationMode = AllocationMode.globalPercent;
  double _globalPct = 30.0; // % of total balance (global mode)
  // For accountSpecific / multiAccount: account name → % slider value
  Map<String, double> _accountPcts = {};
  bool _allocationExpanded = false;

  static const _iconOptions = <Map<String, dynamic>>[
    {'icon': Icons.directions_car_rounded,  'label': 'Car'},
    {'icon': Icons.home_rounded,            'label': 'Home'},
    {'icon': Icons.flight_rounded,          'label': 'Travel'},
    {'icon': Icons.laptop_mac_rounded,      'label': 'Tech'},
    {'icon': Icons.school_rounded,          'label': 'Education'},
    {'icon': Icons.favorite_rounded,        'label': 'Health'},
    {'icon': Icons.shopping_bag_rounded,    'label': 'Shopping'},
    {'icon': Icons.savings_rounded,         'label': 'Savings'},
    {'icon': Icons.directions_bike_rounded, 'label': 'Fitness'},
    {'icon': Icons.restaurant_rounded,      'label': 'Food'},
    {'icon': Icons.music_note_rounded,      'label': 'Music'},
    {'icon': Icons.beach_access_rounded,    'label': 'Vacation'},
  ];
  int _selectedIconIndex = -1;

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
      if (edit.imagePath.startsWith('/')) {
        _pickedImagePath = edit.imagePath;
        _useCustomImage = true;
        _iconSectionExpanded = true;
      }
      // Restore allocation settings
      _allocationMode   = edit.allocationMode;
      _globalPct        = edit.accountAllocations['*'] ?? 30.0;
      if (edit.allocationMode != AllocationMode.globalPercent) {
        _accountPcts = Map<String, double>.from(edit.accountAllocations);
        _allocationExpanded = true;
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
          _selectedIconIndex = -1;
        });
      }
    } catch (_) {}
  }

  String get _finalImagePath {
    if (_useCustomImage && _pickedImagePath != null) {
      return _pickedImagePath!;
    }
    return _selectedIcon;
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

            // ── Customize Icon / Image — TOGGLE SECTION ──────────────────────
            GestureDetector(
              onTap: () => setState(() =>
                  _iconSectionExpanded = !_iconSectionExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111821),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconSectionExpanded
                          ? Icons.palette_rounded
                          : Icons.palette_outlined,
                      color: _iconSectionExpanded
                          ? AppColors.savingProgressGradStart
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
                    // Preview of current icon/image
                    if (!_iconSectionExpanded) ...[
                      const SizedBox(width: 8),
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
                    ],
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

            // ── Collapsible Icon/Image Content ───────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _iconSectionExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon dropdown
                          const Text(
                            'Choose Icon',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildIconDropdown(),
                          const SizedBox(height: 12),

                          // Upload photo
                          const Text(
                            'Or Upload a Photo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Preview
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: const Color(0xFF111821),
                                  child: _buildPreviewThumbnail(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    height: 40,
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
                                        SizedBox(width: 6),
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
            const SizedBox(height: 20),

            // ── Funding Source / Allocation Section ───────────────────────────
            Consumer<FinanceProvider>(
              builder: (context, prov, _) {
                final accountNames = prov.allAccountNames;
                final balances = prov.latestBalancesMap;
                final fmt = NumberFormat('#,##0');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle row
                    GestureDetector(
                      onTap: () => setState(
                          () => _allocationExpanded = !_allocationExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111821),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_rounded,
                              color: _allocationExpanded
                                  ? AppColors.savingProgressGradStart
                                  : Colors.white54,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Funding Source',
                                style: TextStyle(
                                  color: _allocationExpanded
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Summary badge
                            Text(
                              _allocationMode == AllocationMode.globalPercent
                                  ? '${_globalPct.toStringAsFixed(0)}% of all'
                                  : _accountPcts.isEmpty
                                      ? 'Not set'
                                      : _accountPcts.entries
                                          .map((e) =>
                                              '${e.key} ${e.value.toStringAsFixed(0)}%')
                                          .join(', '),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: _allocationExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white54,
                                  size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Collapsible content
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: _allocationExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mode selector
                                  Row(
                                    children: [
                                      _modePill('All Accounts',
                                          AllocationMode.globalPercent),
                                      const SizedBox(width: 8),
                                      _modePill('One Account',
                                          AllocationMode.accountSpecific),
                                      const SizedBox(width: 8),
                                      _modePill('Multiple',
                                          AllocationMode.multiAccount),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Global percent slider
                                  if (_allocationMode ==
                                      AllocationMode.globalPercent) ...[  
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Use ${_globalPct.toStringAsFixed(0)}% of total balance',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
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

                                  // Account-specific / multi-account
                                  if (_allocationMode !=
                                      AllocationMode.globalPercent) ...[  
                                    if (accountNames.isEmpty)
                                      Text(
                                        'No accounts detected yet — send/receive a transaction first.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                              alpha: 0.45),
                                          fontSize: 12,
                                        ),
                                      )
                                    else
                                      ...accountNames.map((name) {
                                        final bal = balances[name] ?? 0;
                                        final pct = _accountPcts[name] ?? 0.0;
                                        final isSelected = pct > 0;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                // Select toggle
                                                GestureDetector(
                                                  onTap: () => setState(() {
                                                    if (isSelected) {
                                                      _accountPcts.remove(name);
                                                    } else {
                                                      _accountPcts[name] = 50.0;
                                                      // For accountSpecific: deselect others
                                                      if (_allocationMode ==
                                                          AllocationMode
                                                              .accountSpecific) {
                                                        _accountPcts
                                                            .removeWhere(
                                                                (k, v) =>
                                                                    k != name);
                                                      }
                                                    }
                                                  }),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 160),
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? AppColors
                                                              .savingProgressGradStart
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
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
                                                            Icons.check_rounded,
                                                            color: Colors.white,
                                                            size: 12)
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
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  'ETB ${fmt.format(bal)}',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.4),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isSelected) ...[  
                                              const SizedBox(height: 4),
                                              SliderTheme(
                                                data: SliderThemeData(
                                                  trackHeight: 3,
                                                  activeTrackColor: AppColors
                                                      .savingProgressGradStart,
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withValues(alpha: 0.1),
                                                  thumbColor: AppColors
                                                      .savingProgressGradStart,
                                                  overlayColor: AppColors
                                                      .savingProgressGradStart
                                                      .withValues(alpha: 0.15),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const SizedBox(width: 28),
                                                    Expanded(
                                                      child: Slider(
                                                        value: pct,
                                                        min: 5,
                                                        max: 100,
                                                        divisions: 19,
                                                        onChanged: (v) =>
                                                            setState(() =>
                                                                _accountPcts[
                                                                    name] = v),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 36,
                                                      child: Text(
                                                        '${pct.toStringAsFixed(0)}%',
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .savingProgressGradStart,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                          ],
                                        );
                                      }),
                                  ],
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),

            // ── Save / Update button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  final title = _titleCtrl.text.trim();
                  final target =
                      double.tryParse(_targetCtrl.text.trim()) ?? 0;
                  final saved =
                      double.tryParse(_savedCtrl.text.trim()) ?? 0;

                  if (title.isEmpty || target <= 0) return;

                  // Build accountAllocations map from current state
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

  /// Pill-shaped mode selector tab
  Widget _modePill(String label, AllocationMode mode) {
    final selected = _allocationMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _allocationMode = mode;
        // Reset account selections when switching mode
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

  /// Compact icon dropdown menu
  Widget _buildIconDropdown() {
    final selectedLabel = _selectedIconIndex >= 0
        ? _iconOptions[_selectedIconIndex]['label'] as String
        : 'Default (Savings)';
    final selectedIconData = _selectedIconIndex >= 0
        ? _iconOptions[_selectedIconIndex]['icon'] as IconData
        : Icons.savings_rounded;

    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<int>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF111821),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('Select Icon',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ...List.generate(_iconOptions.length, (i) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _iconOptions[i]['icon'] as IconData,
                        color: Colors.white70, size: 20,
                      ),
                    ),
                    title: Text(
                      _iconOptions[i]['label'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    trailing: _selectedIconIndex == i
                        ? const Icon(Icons.check_rounded, color: AppColors.positive, size: 20)
                        : null,
                    onTap: () => Navigator.pop(context, i),
                  );
                }),
              ],
            ),
          ),
        );
        if (result != null) {
          setState(() {
            _selectedIconIndex = result;
            _useCustomImage = false;
            _pickedImagePath = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111821),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(selectedIconData, color: AppColors.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  /// Tiny preview thumbnail used in the toggle row and expanded section
  Widget _buildPreviewThumbnail() {
    if (_useCustomImage && _pickedImagePath != null) {
      final file = File(_pickedImagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    if (_selectedIconIndex >= 0) {
      return Center(
        child: Icon(
          _iconOptions[_selectedIconIndex]['icon'] as IconData,
          color: AppColors.gold,
          size: 22,
        ),
      );
    }
    return const Center(
      child: Icon(Icons.savings_rounded, color: AppColors.gold, size: 22),
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

