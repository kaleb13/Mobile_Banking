import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/expense_definition.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../shell/custom_bottom_nav_bar.dart';
import '../../theme/app_theme.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a reason (category) first.')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Please enter a valid number of times per day (1-24).')));
        return;
      }

      if (_recurringType == 'interval') {
        intervalDays = int.tryParse(_intervalDaysController.text.trim());
        if (intervalDays == null || intervalDays <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please enter a valid interval in days.')));
          return;
        }
      } else if (_recurringType == 'specific_day') {
        specificDay = int.tryParse(_specificDayController.text.trim());
        if (specificDay == null || specificDay < 1 || specificDay > 31) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please enter a valid day between 1 and 31.')));
          return;
        }
      } else if (_recurringType == 'days_of_week') {
        if (_selectedDays.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select at least one day.')));
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
      backgroundColor: const Color(0xFF1F1F25),
      extendBody: true,
      bottomNavigationBar: DynamicNavBarWrapper(
        currentIndex: 4,
        onTap: (_) {},
        isDynamic: true,
        heroTag: 'navbar_add_edit_expense',
        dynamicActionLabel: 'Save Expense Definition',
        dynamicActionIcon: Icons.check,
        onDynamicAdd: _saveDefinition,
        onDynamicBack: () => Navigator.pop(context),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Ensures a back button isn't auto-generated here
        title: Text(
          widget.expenseDefinition == null
              ? 'New Expense Definition'
              : 'Edit Expense Definition',
          style: const TextStyle(
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
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
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
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedReason != null
                                  ? Icons.category
                                  : Icons.category_outlined,
                              color: _selectedReason != null
                                  ? AppColors.primaryBlue
                                  : AppColors.labelGray,
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
                                      : AppColors.labelGray,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.labelGray, size: 20),
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
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add,
                          color: AppColors.primaryBlue, size: 24),
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
                label: 'Default Amount (ETB)',
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
              const Divider(color: Color(0x33FFFFFF)),
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
                                color: Color(0xFF9CA3AF), fontSize: 12)),
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
                DropdownButtonFormField<String>(
                  initialValue: _recurringType,
                  dropdownColor: const Color(0xFF1C1F24),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primaryBlue)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'daily', child: Text('Daily (Every day)')),
                    DropdownMenuItem(
                        value: 'interval',
                        child: Text('Custom Interval (Every X days)')),
                    DropdownMenuItem(
                        value: 'specific_day',
                        child: Text('Specific Day of Month')),
                    DropdownMenuItem(
                        value: 'days_of_week',
                        child: Text('Specific Days of Week')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _recurringType = val!;
                    });
                  },
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
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.alertRed, width: 1),
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
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: days.map((day) {
            final isSelected = _selectedDays.contains(day['val']);
            return ChoiceChip(
              label: Text(day['label'] as String),
              selected: isSelected,
              selectedColor: const Color(0xFFF0B90B),
              backgroundColor: const Color(0xFF1C1F24),
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Reason', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Internet Bill',
            hintStyle: const TextStyle(color: AppColors.labelGray),
            enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.labelGray)),
          ),
          TextButton(
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
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Add',
                style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}
