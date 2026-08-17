import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/expense_definition.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_toast.dart';
import '../dashboard/reason_selection_sheet.dart';

class AddEditExpenseDefinitionScreen extends StatefulWidget {
  final ExpenseDefinition? expenseDefinition;

  const AddEditExpenseDefinitionScreen({super.key, this.expenseDefinition});

  @override
  State<AddEditExpenseDefinitionScreen> createState() =>
      _AddEditExpenseDefinitionScreenState();
}

class _AddEditExpenseDefinitionScreenState
    extends State<AddEditExpenseDefinitionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _intervalDaysController;
  late TextEditingController _specificDayController;
  late TextEditingController _timesPerDayController;

  bool _isRecurring = false;
  String _recurringType =
      'daily'; // 'daily', 'interval', 'specific_day', 'days_of_week'
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

    final amount = double.parse(_amountController.text.trim());
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
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: AppButton.primary(
            text: 'Save Expense Definition',
            height: 50,
            onPressed: _saveDefinition,
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          widget.expenseDefinition == null
              ? 'New Expense Definition'
              : 'Edit Expense Definition',
          style: AppTypography.heading2.copyWith(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Expense Details',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AppBottomSheet.show(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => ReasonSelectionSheet(
                            initialReason: _selectedReason,
                            onReasonSelected: (reason) {
                              setState(() {
                                _selectedReason = reason;
                              });
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedReason != null
                                  ? Icons.category
                                  : Icons.category_outlined,
                              color: _selectedReason != null
                                  ? AppColors.gold
                                  : AppColors.textSoft,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedReason?.name ??
                                    'Select Reason / Category',
                                style: TextStyle(
                                  color: _selectedReason != null
                                      ? Colors.white
                                      : AppColors.textSoft,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.textSoft, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Quick Add Reason Button
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add,
                          color: AppColors.gold, size: 24),
                      onPressed: () {
                        _showQuickAddReasonDialog(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'Description',
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _amountController,
                label:
                    'Default Amount (${Provider.of<FinanceProvider>(context, listen: false).currentCurrency.shortLabel})',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  if (double.tryParse(val.trim()) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              const Divider(color: AppColors.border),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recurring Expense',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Automatically deduct this expense on a schedule',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
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
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _timesPerDayController,
                  label: 'Times per Day',
                  hintText: 'e.g., 3 (for breakfast, lunch, dinner)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                const Text('Schedule Type',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                const SizedBox(height: 12),
                AppDropdown<String>.dark(
                  value: _recurringType,
                  items: const [
                    AppDropdownItem(
                        value: 'daily', label: 'Daily (Every day)'),
                    AppDropdownItem(
                        value: 'interval',
                        label: 'Custom Interval (Every X days)'),
                    AppDropdownItem(
                        value: 'specific_day',
                        label: 'Specific Day of Month'),
                    AppDropdownItem(
                        value: 'days_of_week',
                        label: 'Specific Days of Week'),
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
                  maxWidth: 240,
                  isDefault: false,
                ),
                const SizedBox(height: 16),
                if (_recurringType == 'interval')
                  _buildTextField(
                    controller: _intervalDaysController,
                    label: 'Interval (Days)',
                    hintText: 'e.g., 2 (for every other day)',
                    keyboardType: TextInputType.number,
                  ),
                if (_recurringType == 'specific_day')
                  _buildTextField(
                    controller: _specificDayController,
                    label: 'Day of the Month (1-31)',
                    keyboardType: TextInputType.number,
                  ),
                if (_recurringType == 'days_of_week')
                  _buildDaysOfWeekSelector(),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? minLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      minLines: minLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
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
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text('Select Days',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: days.map((day) {
            final isSelected = _selectedDays.contains(day['val']);
            return ChoiceChip(
              label: Text(day['label'] as String),
              selected: isSelected,
              selectedColor: AppColors.gold,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(day['val'] as int);
                  } else {
                    _selectedDays.remove(day['val'] as int);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showQuickAddReasonDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Reason', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Internet Bill',
            hintStyle: const TextStyle(color: AppColors.textSoft),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide.none),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppButton.secondary(
            text: 'Cancel',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            text: 'Add',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final provider =
                    Provider.of<FinanceProvider>(context, listen: false);
                final newReason = await provider.addReason(name);
                if (mounted) {
                  setState(() {
                    _selectedReason = newReason;
                  });
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
