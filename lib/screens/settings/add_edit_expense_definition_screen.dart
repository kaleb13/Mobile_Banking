import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/expense_definition.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_toast.dart';
import '../dashboard/reason_selection_sheet.dart';

/// Drawer-based modal sheet for creating and editing expense definitions & templates.
class AddEditExpenseDefinitionScreen extends StatefulWidget {
  final ExpenseDefinition? expenseDefinition;

  const AddEditExpenseDefinitionScreen({super.key, this.expenseDefinition});

  /// Static helper to present this sheet as an [AppDrawer].
  static Future<void> show(
    BuildContext context, {
    ExpenseDefinition? expenseDefinition,
  }) {
    return AppDrawer.show(
      context: context,
      builder: (ctx) => AddEditExpenseDefinitionScreen(
        expenseDefinition: expenseDefinition,
      ),
    );
  }

  @override
  State<AddEditExpenseDefinitionScreen> createState() =>
      _AddEditExpenseDefinitionScreenState();
}

class _AddEditExpenseDefinitionScreenState
    extends State<AddEditExpenseDefinitionScreen> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _intervalDaysController;
  late TextEditingController _specificDayController;
  late TextEditingController _timesPerDayController;

  bool _isRecurring = false;
  String _recurringType = 'daily'; // 'daily', 'interval', 'specific_day', 'days_of_week'
  List<int> _selectedDays = [];
  AppReason? _selectedReason;

  @override
  void initState() {
    super.initState();
    final def = widget.expenseDefinition;
    _nameController = TextEditingController(text: def?.name ?? '');
    _amountController = TextEditingController(
        text: def != null ? def.defaultAmount.toStringAsFixed(2) : '');
    _intervalDaysController =
        TextEditingController(text: def?.intervalDays?.toString() ?? '');
    _specificDayController =
        TextEditingController(text: def?.specificDay?.toString() ?? '');
    _timesPerDayController =
        TextEditingController(text: def?.timesPerDay.toString() ?? '1');

    _isRecurring = def?.isRecurring ?? false;
    _recurringType = def?.recurringType ?? 'daily';
    if (def?.selectedDaysOfWeek != null &&
        def!.selectedDaysOfWeek!.isNotEmpty) {
      _selectedDays = def.selectedDaysOfWeek!
          .split(',')
          .map((e) => int.tryParse(e) ?? 1)
          .toList();
    }

    if (def?.reasonId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<FinanceProvider>(context, listen: false);
        final reason =
            provider.reasons.where((r) => r.id == def!.reasonId).firstOrNull;
        if (reason != null && mounted) {
          setState(() {
            _selectedReason = reason;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _intervalDaysController.dispose();
    _specificDayController.dispose();
    _timesPerDayController.dispose();
    super.dispose();
  }

  void _saveDefinition() {
    if (_selectedReason == null) {
      AppToast.warning(context, message: 'Please select a reason (category) first');
      return;
    }

    final reasonName = _selectedReason!.name;
    final description = _nameController.text.trim();
    final templateName = description.isNotEmpty ? description : reasonName;

    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      AppToast.warning(context, message: 'Please enter a valid amount');
      return;
    }

    int? intervalDays;
    int? specificDay;
    int timesPerDay = 1;

    if (_isRecurring) {
      timesPerDay = int.tryParse(_timesPerDayController.text.trim()) ?? 1;
      if (timesPerDay < 1 || timesPerDay > 24) {
        AppToast.warning(
          context,
          message: 'Please enter a valid number of times per day (1-24)',
        );
        return;
      }

      if (_recurringType == 'interval') {
        intervalDays = int.tryParse(_intervalDaysController.text.trim());
        if (intervalDays == null || intervalDays <= 0) {
          AppToast.warning(
            context,
            message: 'Please enter a valid interval in days',
          );
          return;
        }
      } else if (_recurringType == 'specific_day') {
        specificDay = int.tryParse(_specificDayController.text.trim());
        if (specificDay == null || specificDay < 1 || specificDay > 31) {
          AppToast.warning(
            context,
            message: 'Please enter a valid day between 1 and 31',
          );
          return;
        }
      } else if (_recurringType == 'days_of_week') {
        if (_selectedDays.isEmpty) {
          AppToast.warning(
            context,
            message: 'Please select at least one day',
          );
          return;
        }
      }
    }

    final newDef = ExpenseDefinition(
      id: widget.expenseDefinition?.id,
      name: templateName,
      defaultAmount: amount,
      isRecurring: _isRecurring,
      recurringType: _isRecurring ? _recurringType : null,
      intervalDays:
          _isRecurring && _recurringType == 'interval' ? intervalDays : null,
      specificDay:
          _isRecurring && _recurringType == 'specific_day' ? specificDay : null,
      selectedDaysOfWeek: _isRecurring && _recurringType == 'days_of_week'
          ? _selectedDays.join(',')
          : null,
      timesPerDay: _isRecurring ? timesPerDay : 1,
      lastAppliedDate: widget.expenseDefinition?.lastAppliedDate,
      reasonId: _selectedReason?.id,
    );

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (widget.expenseDefinition == null) {
      provider.addExpenseDefinition(newDef);
    } else {
      provider.updateExpenseDefinition(newDef);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expenseDefinition != null;
    final currency = Provider.of<FinanceProvider>(context, listen: false).currentCurrency.shortLabel;

    return AppDrawer(
      heightFactor: 0.88,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.positive,
        title: isEditing ? 'Edit Expense Definition' : 'New Expense Definition',
        subtitle: isEditing
            ? 'Update your template amount, category, or schedule'
            : 'Create a template for manual or recurring cash expenses',
      ),
      bottomAction: AppButton.primary(
        text: isEditing ? 'Update Definition' : 'Save Definition',
        height: 48,
        onPressed: _saveDefinition,
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // ── Category / Reason Selector (Full Width) ───────────────────────
          const Text(
            'CATEGORY / REASON',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              ReasonSelectionSheet.show(
                context,
                initialReason: _selectedReason,
                onReasonSelected: (reason) {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.drawerCard,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category_rounded,
                    color: _selectedReason != null
                        ? AppColors.positive
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedReason?.name ?? 'Select Reason / Category',
                      style: TextStyle(
                        color: _selectedReason != null
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: _selectedReason != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Description Input ─────────────────────────────────────────────
          AppTextField(
            controller: _nameController,
            label: 'DESCRIPTION (OPTIONAL)',
            hint: 'e.g. Daily Coffee, Internet Bill',
            backgroundColor: AppColors.drawerCard,
            borderRadius: AppRadius.cardRadius,
          ),
          const SizedBox(height: 14),

          // ── Default Amount Input ──────────────────────────────────────────
          AppTextField(
            controller: _amountController,
            label: 'DEFAULT AMOUNT ($currency)',
            hint: '0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '$currency ',
            backgroundColor: AppColors.drawerCard,
            borderRadius: AppRadius.cardRadius,
          ),
          const SizedBox(height: 20),

          // ── Recurring Section ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.drawerCard,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Recurring Expense',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Automatically deduct on a preset schedule',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSwitch(
                      value: _isRecurring,
                      onChanged: (val) {
                        setState(() {
                          _isRecurring = val;
                        });
                      },
                    ),
                  ],
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _timesPerDayController,
                    label: 'TIMES PER DAY',
                    hint: 'e.g. 1 (or 3 for meals)',
                    keyboardType: TextInputType.number,
                    backgroundColor: AppColors.drawerCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'SCHEDULE TYPE',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppDropdown<String>.dark(
                    value: _recurringType,
                    items: const [
                      AppDropdownItem(
                        value: 'daily',
                        label: 'Daily (Every day)',
                      ),
                      AppDropdownItem(
                        value: 'interval',
                        label: 'Custom Interval (Every X days)',
                      ),
                      AppDropdownItem(
                        value: 'specific_day',
                        label: 'Specific Day of Month',
                      ),
                      AppDropdownItem(
                        value: 'days_of_week',
                        label: 'Specific Days of Week',
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _recurringType = val;
                        });
                      }
                    },
                    height: 46,
                    borderRadius: 14,
                    maxWidth: double.infinity,
                    isDefault: false,
                  ),
                  const SizedBox(height: 14),

                  if (_recurringType == 'interval')
                    AppTextField(
                      controller: _intervalDaysController,
                      label: 'INTERVAL (DAYS)',
                      hint: 'e.g. 2 (every other day)',
                      keyboardType: TextInputType.number,
                      backgroundColor: AppColors.drawerCard,
                      borderRadius: BorderRadius.circular(16),
                    ),

                  if (_recurringType == 'specific_day')
                    AppTextField(
                      controller: _specificDayController,
                      label: 'DAY OF THE MONTH (1-31)',
                      hint: 'e.g. 15',
                      keyboardType: TextInputType.number,
                      backgroundColor: AppColors.drawerCard,
                      borderRadius: BorderRadius.circular(16),
                    ),

                  if (_recurringType == 'days_of_week')
                    _buildDaysOfWeekSelector(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekSelector() {
    const days = [
      {'val': 1, 'label': 'Mon'},
      {'val': 2, 'label': 'Tue'},
      {'val': 3, 'label': 'Wed'},
      {'val': 4, 'label': 'Thu'},
      {'val': 5, 'label': 'Fri'},
      {'val': 6, 'label': 'Sat'},
      {'val': 7, 'label': 'Sun'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT DAYS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: days.map((day) {
            final isSelected = _selectedDays.contains(day['val']);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDays.remove(day['val'] as int);
                  } else {
                    _selectedDays.add(day['val'] as int);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.positive
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  day['label'] as String,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.buttonPrimaryText
                        : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
